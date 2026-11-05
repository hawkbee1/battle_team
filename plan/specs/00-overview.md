# BattleTeam: Game Overview

Status: **ready**. Built through Q&A. Open questions live in `specs/95-open-questions.md`.

## Spec index
- `specs/00-overview.md`: this file, index and record of decisions.
- `specs/10-map-and-terrain.md` with `data/terrain.yaml`: maps, terrain, movement, water, line of sight.
- `specs/20-units-and-progression.md` with `data/units.yaml`: unit stats, XP, skill-point trees, roles.
- `specs/30-special-units-and-victory.md`: the 8 special units, capture and victory.
- `specs/40-newcomers-and-social.md`: newcomer placement, money safety net, communication, players/commanders/sections.
- `specs/50-hq.md`: HQ role, manager, movement, destruction, storage.
- `specs/60-economy.md`: money ownership, earning, spending, transfers.
- `specs/70-combat-and-ap.md` with `data/combat.yaml`: AP, hit resolution, damage, friendly fire, morale, prisoners.
- `specs/80-ai-and-automation.md`: section AI, AI agents through the API, server-managed sections (ready, milestone M1).
- `specs/90-research-topic-priority.md`: research (industry and academic) on what matters most for success.
- `specs/95-open-questions.md`: master list of open questions (to-do / done of the spec phase).
- `specs/96-design-risks.md`: design risks noticed in reviews and not yet addressed.
- `data/battle.yaml`: default values of battle settings.
- `data/economy.yaml`: currency, prices, earnings, transfer fees.
- `data/medals.yaml`: medal tiers and thresholds.
- `milestones/m1-ai-and-automation.md`: section AI, automatic actions and automation (rules, discussion first).
- `milestones/m2-technical-stack.md`: choice of the technical stack; no code before it is done.
- `milestones/m3-pathfinding.md`: pathfinding (before the rules core).
- `milestones/m4-rules-core.md`: headless rules core and its issues.
- `milestones/m5-simulation-host.md`: simulation host, persistence and the data around battles.
- `milestones/m8-revision-after-real-battles.md`: what to review after a few real battles.
- Rule IDs: each rule in specs 10–70 has a stable ID (see `README.md`, Phase 1 step 4).
- Markdown files explain the rules (they teach the game). YAML files hold the numbers (code loads them). Neither depends on the technical stack.

## Decisions so far

### Core
1. Genre: 3D team battle game, several teams at war until one wins.
2. Scale: massive, 100+ players per battle.
3. Persistence: battles are persistent and last days. Players come and go while the battle keeps running on the server.
4. Real time. No turns.
5. Control: players command units from a top-down camera, or enter a unit and play through its eyes.
6. Action points (AP): each unit has a **single AP pool**. Move, attack, build, heal etc. all draw from it. AP regenerate over time up to a per-unit maximum.

### Units and progression (see unit spec)
7. Start: each player starts with 1 commander plus 3 units of another type. (Revised by decision 128: the player buys his units.)
8. XP: each unit earns XP from hits/kills, role actions, objectives, and time survived near the commander.
9. Evolution: a **skill-point tree** per unit type, nodes bought in any order subject to prerequisites.
10. Permanence: units and their XP/evolution persist across the battles of a war, and are lost at the end of the war. Permadeath: a killed unit is lost for good (commander excepted). (Revised: earlier versions said "permanent across battles" without the war limit.)
11. Common stats: HP, AP max, attack, defense, move speed, AP per metre, vision range, movement class, armor type, morale. (Revised by decisions 57-58: armor type added; attack and defense act on hit chance, not damage. Revised by decisions 167-169: AP max is 30 for every unit, AP recovery is one rate for all, and AP per metre is a unit stat.)
12. Unit categories: commanders, engineers, scouts, artillery, transports, vehicles, soldiers, plus radios. (Revised by decision 60: a medic is a soldier with a heal role.)
12b. **Flying is a capability** of some units, not a unit category, a movement class or an armor type.
13. Engineers build or repair: bridges, ladders, walls, roads, traps.
14. Scouts share positions of spotted enemies.

### Commander and sections
15. A commander and his units form a **section**.
16. The commander always resurrects after death. (Revised by decision 125: he resurrects in storage, with his section.)
17. The higher the commander level, the more troops he can command and store. (Revised by decision 79: the level comes from section XP, not from the commander's own XP. Revised by decision 127: section size cap and storage.)
18. A commander gives bonuses to nearby troops of his section: his aura raises their morale.
19. A commander can spend money to buy more troops.

### Controlling units
20. Both modes coexist: the player gives direct orders from the top-down camera, or enters a unit. Units that are not directly controlled follow simple section AI behaviours (follow commander, hold, patrol...). (Revised by decision 156: player units have no behaviours of their own and act only on orders.)

### Vision
21. Fog of war, **shared per section only**: a section sees what its own units see. Radios extend this sharing (see Radio).
22. Mountains and buildings block line of sight (3D). (Revised by decision 87: forests conceal in proportion to the forest length crossed; destroyed objects stop blocking.)

### Economy
23. Money is earned from: successful hits, engineer constructions, enemy deaths, enemy HQ hits and HQ destruction.
24. Medics earn money for their section when they heal other units.
25. Money belongs to the section (no team or guild treasury). It is kept between battles of a war.
25b. Money can be transferred between players of the same team with fees (destroyed); fees are lower between sections of the same guild. The transfer + safety-net loop is accepted.
25d. Constructions cost no money, only AP and time.
25c. Newly bought troops appear in storage (homeland), then deploy through the section's portal. (Revised by decision 130: they arrive next to the guild camp or the HQ.)

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
33. Players can join a running battle at any time, spawning a commander + 3 units at their team's starting point (catch-up mechanics: to be defined). (Revised by decisions 82, 128 and 129: no catch-up; the commander arrives at the guild camp or the HQ, and the player buys his units.)

### Radio (purchasable unit)
34. A **radio** is a special unit that **a commander can buy from the start**.
35. A radio gathers information from the team scouts located in its area. Its **range** is a characteristic that can evolve.
36. The information gathered by a radio is shared with **all the sections** (of the radio's team).
37. A radio is movable but very slow and too big to be carried by a transport. It is a different object from the 8 map special units.

### Combat and AP (see combat spec)
37b. AP regenerate at a constant rate, whatever the unit does. (Revised by decision 168: 1 AP per hour.)
37c. Hits are hybrid: aim-based when a player is inside a unit, hit chance when units act under orders or AI.
37d. Damage uses a weapon-type vs armor-type table. Friendly fire is on, full damage.
37e. Cover blocks shots; partial cover lowers the chance of being hit (revised by decision 65: no damage reduction). Units in a destroyed transport are ejected with heavy damage.
37f. At 0 HP a unit normally dies. Only when a commander deals the final blow himself, low morale and low AP raise the odds that it is taken prisoner, or switches side into the attacker's section if it has room (keeping its XP and evolution). Prisoners can be exchanged or ransomed. (Revised by decisions 131 and 149: never through friendly fire, never for commanders or camps.)
37h. Each weapon has a firing speed, a cartridge (magazine) capacity, a loading speed, an unloading speed, and says whether the unit can move with it loaded. (Decision 150: a 1-round weapon fires once per reload.)
37g. Morale is changed by the commander aura, nearby kills and ally deaths, and being outnumbered.

### Map and world (see map spec)
38. Maps are **hand-authored**. Team count and map size are **settings of a battle**.
39. Terrain changes persist during a battle: engineer constructions, destructible trees and buildings, craters from weapons.
40. Movement classes: foot, wheeled, tracked (flying units use a flying movement profile). AP cost depends on class, terrain type and a slope factor. (Revised by decision 133: slope is signed.)
41. Rivers and lakes are impassable for most units; boats, amphibious units, flyers and bridges cross them.
42. Floating islands are reached by flying, or by engineer-built bridges/ladders from nearby terrain.

### Map special units (the 8 objectives) and victory
43. At battle start, 8 special units (name still to be decided) are placed on solid ground. (Revised by decision 96: they are relics.)
44. They are movable objects, but move very slowly and are too big to be carried by a transport.
45. Victory: only one HQ remains, OR one team controls 5 special units for 24 hours.
46. Special units are taken by a capture action and stay owned until recaptured. They give nothing besides the victory timer.
46b. The 8 special units are ancient relics. Any unit next to a relic can capture it; a capture is blocked while enemies are near; the previous owner is alerted.
46c. The 24-hour victory timer resets fully as soon as the team holds fewer than 5 relics.
46d. A relic moves only when pushed by units of its controlling team. It cannot fly or cross water, forests, towns or walls. It can fall from a floating island when pushed over the edge. Pushed hard enough, it crushes units in its path. (Revised by decision 138: crushing kills.)
46e. Pushing needs a minimum number of pushers, costs AP, and moves the relic at a fixed slow speed. Crushed units of any team take heavy damage. A relic falling from an island lands intact below, keeps its owner and crushes what is under. Relics cross water only on reinforced bridges built by engineers. (Revised by decision 138: crushed units die; push speed; pushers without AP wait.)
46f. A relic crushes only when pushed with more than the minimum number of pushers. Slopes change the push effort. Relics are indestructible. A walled-in relic stays stuck until the walls are destroyed.

### HQ (see HQ spec)
46g. HQ manager powers: team-wide orders and map markers, and moving the HQ. The manager is the player with the most medal points (delegation possible).
46h. The HQ is pushed by units like a relic, with the same obstacles. The manager is fixed at battle start (delegation only). (Revised by decision 177: the HQ is not pushed, it moves on its own.)
46h1. A pushed HQ does not crush units, it pushes them sideways (revised by decision 177: a unit in its path ends the move). No fallback if the manager is offline: he must delegate.
46h3. A section in a guild stores its units in its guild encampment; a section without guild stores them in the HQ. A unit next to its storage place is stored immediately; elsewhere it can be recalled after a long delay that nothing stops. Stored units deploy instantly next to their storage place, except while an enemy is next to it. Storage capacity is limited per section and grows with the commander level (decision 79). (Revised by decision 127: storage capacity = 2 × section size cap.)
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
49f. Teams are created automatically at the start of each battle (rule to be defined); guild members always stay together in the same team. (Revised by decision 103: balanced by team power.)
49g. War and battle statistics are available during and after the war.
49h. After a war, a player keeps his statistics, war medals and permanent game medals.
49i. Cosmetics for sections and units are bought with real money during a war and kept after it, to be applied to other units.
50b. No in-game spying on communications. Most communication may happen on a Discord server.
50. Team, guild and direct player communication are fundamental features.
51. A section is owned by one commander only. A player can have several sections (commanders), but only one commander per battle; several battles run at the same time.

### Weapons, AP and vision (rules core, see combat and map specs)
52. Weapons are items. A unit has one weapon slot and a per-type list of allowed weapon types. A newly bought unit comes with its type's default weapon (included in its price); other weapons are bought with section money.
53. Weapons are equipped or swapped only while the unit is stored or next to its storage place. A killed unit drops its weapon; any unit of any team whose allowed list includes it can pick it up on the spot for an AP cost, dropping its own weapon in its place. Dropped weapons vanish after a delay. (Decision 151: spare weapons are kept in storage.)
54. Ammo is unlimited; only the loaded magazine is limited. A reload always gives a full magazine and discards the rounds left in it.
55. Reloading, unloading and swapping weapons cost time only, no AP. Shots, movement, weapon pick-up and role actions cost AP.
56. A unit with 0 AP is never frozen: it keeps moving as fast as its AP regenerate; a shot or role action waits until it has enough AP. (Revised by decision 132: an action the unit cannot do is refused; decision 138: a pusher without AP waits.)
57. Damage = weapon base damage × weapon-vs-armor multiplier (× airborne_factor against a flying target). Every unit has an armor type. The airborne_factor rule is confirmed (0 = cannot hit flying units).
58. `attack` is accuracy (hit chance under orders/AI, tighter spread in first-person aim). `defense` is evasion (lowers the chance of being hit). Neither changes damage.
59. A unit fires only at targets it sees itself, up to weapon range. Effective vision = vision range × weather factor × terrain factor of the observer's position + height bonus, then hard line-of-sight blockers apply. Weather is a battle state that changes over time.
60. A medic is a soldier with a heal role (category soldier).
61. Roster v1 adds jeep (vehicle, wheeled), tank (vehicle, tracked), truck (transport, wheeled), helicopter (flying capability) and boat (boat capability, water only) to commander, soldier, medic, engineer, scout, artillery and radio. Stats are placeholders. (Revised by decision 86: `sail` replaces the `boat` capability; decision 141: the guild camp is a unit too.)

62. Indirect fire: weapons flagged `indirect_fire` (artillery) may target a ground position that a unit of their section sees, or that a scout reports through a radio in range, with a lower hit chance. All other weapons need their unit's own sight. (Decision 154: where a missed shot lands.)
63. Picking up a dropped weapon costs AP (the only weapon handling that does; see 55).
64. Prisoners and defectors keep their weapon. Units with no weapon (radio, truck) cannot attack.
65. Hit chance under orders/AI = weapon base accuracy × (1 + (attack − defense)/100) × distance × cover × size × speed factors (× indirect factor), clamped to 5–95 %. Partial cover lowers hit chance only, never damage. (Clarified by decision 135: full cover still leaves the 5 % minimum.)
66. Build, repair, heal and capture cost a fixed AP amount paid up front, then take a duration (revised by decision 91: heal is instant; building costs per structure: decision 113); a unit needs the AP to start. Pushing a relic or the HQ costs each pusher AP per metre, like movement, with the slope factor. (Revised by decisions 170-171: capture and push are paid into team pots.)
67. An interrupted action loses the AP paid but keeps its progress; resuming costs the AP of the remaining part. Exception: a capture interrupted by an arriving enemy loses its progress (decision 97).
68. Flying units can land and take off (time, no AP). Landed, they move with their ground class, are hit as ground targets and can load/unload troops. Each map sets a maximum flying altitude. (Revised by decision 142: the map's highest terrain + 10 m.)
69. Weapon values in `data/combat.yaml` are the accepted starting point for the first milestone; they are tuned with headless simulations and playtests.

### Morale, prisoners, defectors, radio (see combat spec)
70. Morale goes from 0 to 100, starts at a base value (50) and changes only through events (commander aura, nearby kills and ally deaths, being outnumbered). No drift.
71. Morale slightly scales the attacker's hit chance (factor 0.9 at morale 0 to 1.1 at 100).
72. 0-HP odds when a commander deals the final blow: p(spared) = 0.6 × ((100 − morale)/100 + (1 − AP/ap_max)) / 2. A spared unit defects or becomes a prisoner, 50/50; defection needs room in the attacking section, else prisoner. (Revised by decisions 131 and 149: never through friendly fire, never for commanders or camps.)
73. A prisoner goes instantly to the captor section's prisoner storage (separate and unlimited, decision 94) and cannot fight or escape. Exchanges and ransoms are negotiated in game between section owners; a ransom goes entirely to the captor section. Prisoners never released are lost at war end.
74. A defector is an ordinary unit of its new section (it can be killed, captured or defect again). Statistics count a defection for the captor and a loss for the previous owner.
75. No extra limit on defections beyond the commander-only rule; watch the snowball effect in playtests.
76. A radio is a normal unit: bought with money, destructible, can be taken prisoner or defect, stored like any unit; unarmed. Its relay range starts at its base value and grows through its skill tree.

### Progression, commander death, between battles (see unit spec)
77. Hit and kill XP is multiplied by 1 + target XP / attacker XP (capped at ×3). Repeated XP from the same target or build spot within a time window shrinks. Hitting allies gives no XP.
78. Each unit spends its own XP on its own skill tree, the commander included. Nodes are permanent (no respec) and never exclude each other.
79. A share of every XP point earned by a unit moves to its section's XP. Section XP sets the commander level, which sets section size cap and storage capacity. Section XP cannot be spent on stats. (Revised by decision 127.)
80. A dead commander respawns at once (revised by decision 125: in storage, not on the field). He loses a share of his unspent XP, never his level. All units of his section on the field go instantly to storage and lose AP and morale. These losses are battle settings.
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
97. Capture takes 30 min and 50 AP (revised by decision 170: the 50 AP are a team pot). One radius (default 30 m) is used to capture and to block: every unit inside it counts, whatever its state (carried, flying, offline). A capture interrupted by an enemy entering the radius loses its progress. Duration, AP and radius are battle settings.
98. Pushing needs at least 10 pushers. Slope changes the effort exactly as for movement. (Revised by decisions 133 and 138: signed slope, push speed, pushers without AP.)
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
108. Guilds: the creator is the chief (guild commander); he can hand the role to another member and can disband the guild, and cannot leave while chief (roles: decision 146; who can create a guild: decision 155). Maximum guild size depends on the guild level, which rises with the total XP earned by its sections while in the guild. A guild can have a single section. A section can play without a guild (storage at the HQ).

### HQ, storage, economy (round 3)
109. Any unit of the team can push the HQ (revised by decision 145: units with the `push` action; decision 177: the HQ is not pushed). HQ hit points: 1000 (battle setting).
110. Deploying a stored unit costs it 10 AP; it is then fully operational. Stored units regenerate AP up to their maximum. A unit within 10 m of its storage place is stored at once; from anywhere else a recall takes 6 hours. An enemy within 20 m of a storage place blocks deployment (and the arrival of new units, decision 147).
111. Guild encampment: 500 w€, 300 HP.
112. Default price of anything not priced: 100 w€. Money earned: hit 1, kill 5, construction 5, heal 5, HQ hit 10, HQ destruction 100. Transfer fees: 2 % inside a guild, 7 % outside. XP cannot be bought. No limit against build-and-destroy farming.

### Round 4
113. Constructions cost AP paid up front plus a build time per structure, and no money (confirms 25d).
114. The HQ and the encampment have no numeric armor: their armor types are `hq` and `structure`.
115. Crushing: with 10 + n pushers a relic crushes up to n units in its path; with more blocking units it stops. (Revised by decision 138: crushed units die.)
116. A relic lost with a destroyed reinforced bridge leaves the battle; a team still needs 5 relics for the timer, so with fewer than 5 left only the HQ victory remains. A lost HQ eliminates its team, as if destroyed.
117. A relic pushed over the edge of a floating island falls (decision 46d confirmed; an HQ too, decision 148).
118. Skill trees give stat bonuses only, no abilities. Every evolved stat is capped at 300 % of its base value. (AP max and AP recovery are not evolvable: decision 167.)
119. Scout observe: +30 m vision for 30 minutes, 10 AP; the scout cannot move while observing.
120. A player never leaves a battle and stays in his team for its whole duration. He can store his whole section and deploy again when he wants, but not before 24 hours after his last alive unit was stored.
121. Medal points: bronze 1, silver 3, gold 10. The HQ manager is the player with the most points; ties go to the commander with the most XP.
122. A player can join a running war at any time and enters the current battle.
123. In-game communication is limited to pings, team chat and map markers. Chat and voice happen on Discord, except team chat, which is synced between the game and Discord.
124. A player has one commander per war and can take part in several wars at the same time.

125. A dead commander resurrects **in storage**, with his section (stored at once, decision 80), so an inactive player's commander cannot die again and again. A commander's death does **not** start the 24-hour lock of decision 120: the section can deploy again at once, each unit paying 10 AP (decision 110).
126. Game and Discord accounts are linked. Access to Discord channels depends on the player's sections (their wars, teams and guilds).

### Round 5 (review of 2026-10-26)
127. **Section size.** The section size cap is the number of **active** units (on the field), the commander included. It is **5** at commander level 1 and grows by **1 every 5 commander levels**. A section owns at most **2 × cap** units (active + stored); its storage capacity is 2 × cap, so all its units always fit in storage. The guild camp and the HQ do not count toward the cap and cannot be stored.
128. A new section starts with its commander and its starting money (500 w€, decision 102). The player buys his first units with it; at level 1 the cap leaves room for 4 of them on the field.
129. A new section joins a guild by default, as a **trainee**. Its units arrive at the guild camp, or at the HQ if the guild has no camp. Nobody spawns at the team's starting point.
130. A bought unit arrives next to the guild camp, or next to the HQ if the guild has no camp or the section has no guild. Buying needs free room in the section.
131. Friendly fire never takes a prisoner or causes a defection: only a commander's final blow on an **enemy** unit can.
132. Each unit type lists the **actions it can do**; an order for any other action is refused. A unit never lists an action that costs more AP up front than its `ap_max`.
133. Slope is **signed**: going uphill costs more AP, going downhill costs less, for moving and for pushing. A slope steeper than the class maximum is impassable both ways.
134. Swapping a weapon takes **5 s** (time only, no AP).
135. Full cover gives a cover factor of 0, and the 5–95 % clamp still applies: a unit in full cover keeps a 5 % chance of being hit under orders or AI. In first person, full cover blocks shots completely.
136. Only **bombard** attacks have splash. Every unit within the splash radius is hit at once, without its own hit roll; damage decreases with the distance from the impact point. (Decision 152: the explosive charge never misses.)
137. Terrain objects (trees, buildings, constructions) have an armor type, `structure` by default. Ejection damage is a share of the unit's maximum HP. Default values, adjusted later.
138. A pushed relic or HQ moves at a fixed speed of **5 m per hour** (`push.speed_m_per_h`). A pusher with no AP left stops and waits for AP; the relic or HQ moves only while at least the minimum number of pushers push. (The AP part is revised by decision 171: the push pot.) **Crushing kills**: a unit crushed by a pushed or a falling relic dies.
139. **Heal and repair** work on every friendly unit except the HQ.
140. **Capture progress belongs to the team.** When the capturing unit leaves or dies, another unit of its team inside the radius can resume, paying the AP of the remaining part. An enemy entering the radius still erases the progress (decision 97).
141. The **guild camp** (encampment) is a unit of the guild chief's section. It does not count toward his cap and cannot be stored. It moves slowly on its own, cannot fly, and can heal units.
142. A flying unit cannot fly higher than the map's highest terrain point + **10 m**.
143. Statistics and medals are computed from the battle logs, and they track friendly kills.

### Round 6 (2026-10-31)
144. Commander levels go from **1 to 60**. The section size cap grows at levels 6, 11, ..., 56, up to 16 at level 60. The section XP of each level is in `data/units.yaml` (placeholder curve).
145. The default action lists of `data/units.yaml` are accepted: the radio and the guild camp neither capture nor push; the helicopter and the boat capture but do not push; the camp's heals earn money for the chief's section.
146. Guild roles: **chief**, **member**, **trainee**. A trainee is a new member that the chief has not accepted yet. A guild has two chats: one for the chief and the members, one for the whole guild.
147. An enemy within 20 m of a storage place also blocks the **arrival of new units** there. (A new section's commander is never blocked: decision 210.)
148. A pushed HQ can go over the edge of a floating island and **fall**, like a relic: it lands intact and kills the units under it. (Revised by decision 177: the HQ moves on its own and falls when ordered over the edge.)
149. An enemy **commander** or a **guild camp** is never taken prisoner and never defects.
150. A **1-round weapon** fires once per reload: the time between two shots is its reload time.
151. Bought weapons and swapped-out weapons are kept in the section's **storage** until a unit takes one.
152. The engineer's explosive charge is a **bombard** attack that **never misses**, like a trap: it goes off on the aimed point and its splash hits every unit around it. Artillery shots keep their hit chance (decision 62).
153. When the chief refuses a trainee, nothing else happens to its section: it has no guild, stores its units at the HQ, and can apply to another guild.
154. A missed artillery shot lands away from the aimed point, in a random direction, at a distance proportional to how much it missed. The landing point always stays within the weapon's range from the artillery. Splash damage around the impact point does not depend on the range.
155. A guild can be created by any section that is not in a guild and whose commander is **level 10** or more.
156. **No automatic action for player units.** A unit controlled by a player, or acting for a player through the API, fires, moves, heals, repairs, captures, pushes and builds only on an order. A unit without an order does nothing. The same holds for units of an offline player, which stay passive (decision 29).
157. **AI agents play by the same rules as players.** An AI agent acting through the API has the same rules and limits as a human player. Only the rate of its calls is limited, to stop floods.
158. **One API key per account.** Each user account has one API key. It identifies the user on every call, and every action sent with it is attributed to that user.
159. **Server-managed sections look the same as other sections.** The server creates and runs some sections. Players see them as ordinary sections. Their purpose is not written in the specs.
160. **Server-managed units fire on a chance.** A unit of a server-managed section that sees an enemy within its weapon range may fire. The chance is checked every 30 minutes, and is the same at each check. It is not rolled each time an enemy enters range. The chance and the interval are placeholders in `data/battle.yaml`, to be set later.
161. **API key revocation.** A user can revoke their own API key, and an admin can revoke any key.
162. **Who acted.** Every action records whether the player did it or an AI did it, according to the API key used. (Revised by decision 166: the server is a third origin.)
163. **Server-managed sections have the same capabilities as a normal section.** They can do everything a player's section can do.
164. **Server-managed shots follow the normal rules.** A shot by a server-managed unit uses the hit chance of COMBAT-15, like any unit acting under orders.
165. **The server orders through the API.** The server gives the orders of its sections through the same API as AI agents. The engine that triggers these calls is developed in a later phase; the specs do not describe it.
166. **Three origins.** Every action records its origin: **player** (a player's session), **AI** (an API key), or **server** (the server's own calls for its sections). Refines decision 162.

### Round 7 (2026-11-01)
167. Every unit has an AP maximum of **30**. Evolution does not raise AP maximum or AP recovery.
168. AP recovery is **1 AP per hour** for every unit, constant, while moving, fighting, idle or stored. It is not a unit stat (revises decision 37b and COMBAT-02). Decision 172 makes the rate a battle setting.
169. Movement cost is **per unit**: `ap_per_m` is the AP per metre on flat ground (infantry 1, tank 0.2, jeep 0.1). The movement class and the terrain multiply it (`ap_multiplier`, grass 1.0), and the slope multiplier still applies. `move_speed` stays as the time per metre (revises MAP-15 and COMBAT-03).
170. **Capture is a team pot.** The 50 AP are put into a pot by units inside the capture radius, 5 AP per action, as often as they like. The 30-minute capture starts when the pot is full. An enemy entering the radius loses the progress and the pot (RELIC-08). One unit has at most 30 AP, so it cannot pay 50 AP alone (revises decisions 66 and 97).
171. **Push is a team pot.** Pushers add 5 AP per action to the team's push pot, as often as they like, and the pot pays for the push: pushers no longer pay their own AP per metre. The minimum of 10 pushers still applies (revises the AP part of decision 138). Price per metre, ground and slope: decision 175.
172. The AP recovery rate is a **battle setting**, `ap.recovery_per_hour` in `data/battle.yaml`, default **1 AP per hour**. Special events can use another rate (refines decision 168).
173. **Pots keep their AP.** A partly filled capture or push pot stays until it is used up or control is lost (what counts as control loss: decision 176). A capture's 30-minute timer starts when its pot is full.
174. **Speeds follow real units.** `move_speed` (m/s) is set close to what a real unit of that kind does. A flying unit never goes faster than the jeep, and a sailing unit never faster than the tank. (Base speeds only: decision 178.)

### Round 8 (2026-11-01)
175. **Push profile.** A pushed relic or HQ has its own movement profile, `push`, in `data/terrain.yaml`: a slope row (signed factor, steepest slope, downhill floor) and a ground multiplier per terrain type. Mud and sand make a push dearer and a road cheaper, as slope does. Forests, towns, mountains and water are impassable. Each metre pushed costs `push.pot_ap_per_m` from the push pot, **10 AP** on flat grass, times the ground and slope multipliers. All these values are placeholders. Settles the price and slope part of decision 171.
176. **What empties a pot.** Each relic has **one push pot**, for the team that owns it. It empties when another team captures the relic or when the relic falls from a floating island. A capture pot empties when an enemy enters the capture radius, from the first AP put in, even while no unit of its team is inside. Settles the control-loss part of decision 173.
177. **The HQ is not pushed: it moves on its own.** The HQ manager (HQ-05), or the player he delegated the role to, orders each move. The HQ has its own AP: **30** at most, recovering at the battle rate (decision 172). Each metre costs **0.2 AP** on flat grass, times the ground and slope multipliers of the `push` profile (decision 175): mud, sand and uphill drain its pool, a road or downhill saves AP. It moves at **5 m per hour**, slower than any unit. **Any unit in its path**, friend or enemy, **ends the move order**, and the manager must order again; the HQ never crushes and never pushes units aside. It can go over the edge of a floating island and fall when the manager orders a path over the edge. The values are placeholders. Revises decisions 46h, 46h1, 109 and 148.
178. **Speed caps apply to base speeds.** The caps of decision 174 hold for base `move_speed` only. Evolution raises any speed up to 300 % of its base (decision 118), so an evolved flyer or sailing unit can outrun a jeep or a tank that has not evolved.
179. **Capture XP is split by AP.** When a capture succeeds, its XP (`xp_sources.capture`, 50) is shared among the units that put AP into its pot, in proportion to the AP each one put in: 1 XP per AP with the default numbers. Units that died or left the radius since still get their share. A lost pot pays no XP. The section share applies as usual.
180. **Ground and slope change only the AP cost.** `move_speed` is the same on every ground and slope. Rough ground and slopes slow a unit only through its AP: once its pool is spent, it moves as fast as its AP come back.
181. The `ap_per_m` placeholders are accepted: artillery, radio and guild camp **0.2**; truck, helicopter and boat **0.1**. They are tuned with the scenario harness (M4 Issue 11).
182. **Infantry runs.** Infantry keeps running speeds, 4 to 7 m/s: a 30 m pool is a short dash. The radio moves at **5 m/s** and the guild camp at **1 m/s**.
183. **First-person shots fly.** In first-person control a shot is a projectile that travels at its weapon's speed (`projectile_speed_mps`: rifle 900, machine gun 850, anti-tank 300, anti-air 600 m/s). The player's aim gives its direction, the spread deviates it at random, and it hits the first unit, HQ or obstacle on its path. Each unit type and the HQ have a hit volume (`hit_box_m`: width, length, height), close to the real thing. All values are placeholders. Artillery keeps its rolled indirect fire and the explosive charge never misses, so neither flies.
184. **Observe raises the vision range.** The scout's observe bonus (+30 m, decision 119) is added to its `vision_range`, before the weather and terrain factors: in fog (factor 0.4) it adds 12 m.
185. **Crushing goes unit by unit.** A relic pushed by 10 + *n* pushers crushes the first *n* units it meets on its path, one by one, and stops at the next one.
186. **Friendly fire hurts the own HQ.** The own team's fire, splash included, damages its HQ like any other target (COMBAT-34).
187. **A weapon that changes hands arrives unloaded.** A weapon taken from storage in a swap, or picked up from the ground, must be reloaded before it fires. A newly bought unit's default weapon comes loaded with a full magazine.

### Round 9 (2026-11-02): after M3 and M4
188. **A move pays each terrain it crosses.** Where a move goes from one terrain to another, each terrain is paid for the distance on it, with the slope of the move (MAP-41).
189. **A bridge deck costs as road** for every unit, relic and HQ that crosses it (MAP-42).
190. **Ladders are for foot units.** Climbing a ladder, up or down, costs the height climbed, priced as flat ground of the terrain at its far end: 1 AP per metre for infantry on grass (MAP-43).
191. **Buildings and walls stop ground units**, as walls stop relics (RELIC-20). Trees do not. Flying units ignore all of them. A wall at the end of a bridge or at the top of a ladder stops ground units too (MAP-44).
192. **Flying to and from a floating island is free:** a flying unit pays no AP to go up to an island or down from it, under the altitude limit (MAP-45).
193. **A fall is free and lands next to the edge.** A relic or the HQ that goes over a floating island's edge pays no AP for the fall. It lands on the ground just past the edge, whatever its terrain, but never onto a building or a wall, and its path goes on from there (MAP-39).
194. **A crater is a bowl.** Its depth at a distance *d* from its centre is `depth × (1 − (d / radius)²)`. Where craters overlap, the deepest one counts. Craters dig the ground only, never a floating island (MAP-46).
195. **No cutting corners.** A move never passes between two places when one of them is impassable for it (a wall's corner, a river's bend): it goes around (MAP-47).
196. **Server-managed units fire at 50 % per check.** At each 30-minute check (decision 160), a server-managed unit that sees an enemy within its weapon's range fires with a chance of **50 %**. Both values are placeholders in `data/battle.yaml` (`server_managed`).
197. **Earned XP counts.** Target scaling (UNIT-09) and team power (UNIT-12) use the XP a unit has earned, spent on its tree or not. Buying a node never makes a unit a weaker target or lowers its team's power.
198. **Same build spot: within 10 m.** For anti-farming (UNIT-10), a build within **10 m** of one of the same unit's builds in the window counts as a repeat (`diminishing.same_spot_radius_m`, placeholder).
199. **No XP for time near the commander.** Units earn XP from hits and kills, role actions and captures only. Revises decision 8.
200. **Whole w€.** Every amount of money is a whole number of w€. A fee is rounded to the nearest whole w€, halves up.
201. **A killing shot earns both.** The shot that kills a unit earns the hit's XP and money as well as the kill's.
202. **No money from allies.** Hitting an ally or the own HQ earns no money, as it earns no XP (UNIT-10).
203. **The fee comes out of the amount.** A transfer of 100 w€ outside the guild gives the receiver 93 w€; the 7 w€ fee is destroyed. The sender never pays more than he sends.
204. **The last unit to leave the field starts the lock.** The 24-hour lock (decision 120) starts once no unit of the section is on the field, however the last one left it: stored, recalled, killed, taken prisoner or defected. It runs from that moment. Only a commander's death never starts it (decision 125). The guild camp, which is never stored, and the section's units held prisoner do not count.
205. **A blocked arrival refuses the purchase.** While an enemy within 20 m blocks the arrival of new units (decision 147), or the section is under its 24-hour lock, nothing is bought and no money is spent: a bought unit arrives on the field.
206. **A transport is stored empty.** A loaded transport cannot be stored or recalled: its passengers get off first. A recalled transport takes no passengers. At a commander's death, the units of other sections his transports carry are set down where they are; his own section's carried units are stored with the rest (UNIT-29).
207. **A commander's XP loss lowers his earned XP too.** The XP he loses at his death (UNIT-29) come off his earned XP as well as his unspent XP: a kill on him is worth less, and his team's power drops.
208. **An eliminated team's camp is stored.** When a team is eliminated, its guild camps on the field are stored with its other units (HQ-20), the one exception to "never stored": the guild chief's section keeps its camp for the next battle of the war.
209. **Trainees stay with their guild.** When teams are balanced (decision 103), a trainee section is kept in its guild's team like the chief and the members.
210. **A new commander always arrives.** A new section's commander arrives next to his portal even when an enemy is within 20 m: the block of decision 147 applies to bought units only.
211. **Exact ties are drawn.** A newcomer facing teams of the same lowest power, or HQ manager candidates with the same medal points and commander XP, is settled by a draw with the battle's seeded random.
212. **Every battle starts in storage.** At the start of each battle of a war, every unit of a section is in storage, its guild camp included. Units deploy from their portal; until the chief deploys the camp next to the HQ, the guild uses the HQ portal.
213. **Trainees count toward a guild's size.** A full guild takes no new trainee and is not offered to newcomers.
214. **The camp follows the chief.** When the chief hands his role to a member, the guild camp passes to the new chief's section. When he disbands the guild, the camp is destroyed.
215. **Only the chief opts the guild in or out** of the newcomer list.
216. **Starting positions.** A relic may start on a floating island, on any cell that is not water. An HQ starts on the ground, never on a floating island.
217. **Objects stand on land.** Trees, buildings, walls, traps and roads never stand on water. Bridges stand only on water, with land at both ends. Nothing else limits where a map puts its objects.
218. **The number of relics comes from the data.** A map places at least `relics_to_hold` relics, so they can win, and fewer than twice as many, so no tie is possible (RELIC-17).
219. **Who chooses a pushed relic's path.** The player whose unit first tries to move the relic while its push pot is empty chooses the path. Later pushes add to the pot and follow that path until the pot is empty again.
220. **The HQ manager is the first to log in, until a higher-ranking player logs in.** The first player of a team to log in to the battle becomes its HQ manager, so a team left empty at the battle start gets one with its first newcomer. Each time a player of the team logs in to the battle, the role passes to him if he ranks above the current manager (medal points, then commander XP, decision 121). The manager can still delegate the role (HQ-05). Revises HQ-07, which fixed the manager at the battle start.
221. **Guild levels.** A guild's XP counts every XP point its sections' units earn while in the guild, and gives its level on the `commander_levels` curve. The guild holds 5 sections at level 1 and one more every 5 levels, 16 at level 60 (`progression.guild_size`, placeholders).
222. **A battle's time goes on while its server is stopped.** The time a battle's server spends stopped (a crash, an upgrade) counts as battle time with no order: AP recover, and the timers due then (captures, recalls, locks, the victory hold) end as soon as the battle comes back, so a team can win during an outage. Orders sent while the server is stopped are lost (decision 3).
223. **A spared target earns the kill's XP, not its money.** A commander's final blow that takes its target prisoner or turns it (COMBAT-38) earns the kill's XP (UNIT-05) but not the kill's money (ECO-18). The hit's XP and money stay.
224. **Hitting an HQ earns XP.** A hit on an enemy HQ earns **2 XP** and its destruction **10 XP**, besides their money (ECO-18). The shot that destroys it earns both, as for a kill (decision 201). Values in `data/units.yaml` (`xp_sources.hq_hit`, `hq_destruction`).
225. **Pushers stay inside the radius.** A relic's pushers are the units of its owner that put AP into its push pot since the pot was last empty, are still on the field, and stand **inside the capture radius** of the relic (RELIC-09). The relic moves only while at least 10 of them are inside.
226. **Craters and shots on objects.** A shot of a weapon that deforms the terrain digs a bowl at its impact point, as wide as the weapon's `splash_radius_m` and `craters.depth_per_shot_m` deep at its centre (MAP-46, placeholder in `data/terrain.yaml`). An object takes a bombard shot's splash damage like a unit, and a first-person shot that stops on an object damages it.
227. **A login takes the role from a delegate only by rank.** A player who logs in takes the HQ manager role from a player it was delegated to only if they would take it without the delegation: they are compared with the player who would hold the role had nobody delegated it, the first to log in or the last to take it by rank (decision 220). An exact tie is drawn (decision 211).
228. **A server-managed unit fires at the nearest enemy unit.** At its fire check (AI-07), a server-managed unit fires at the nearest enemy unit it can fire at, the first by unit ID among those as near; never at an HQ or an object. It gives one order to fire, which waits for AP or is refused like any order. A unit carried in a transport does not fire at its check.
229. **Fire checks every 30 minutes from the battle start.** The fire checks of server-managed units fall 30 minutes after the battle starts, then every 30 minutes (`check_interval_s`), for all of them together. A unit that joins a server-managed section later, bought or turned, is first checked at the next of these checks.

## Open questions
All open questions are tracked in `specs/95-open-questions.md`. Design risks are tracked in `specs/96-design-risks.md`.
