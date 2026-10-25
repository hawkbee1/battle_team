# Open questions (master list)

This is the to-do / done list of the spec phase. Tick a question when it is decided and note the decision number from `00-overview.md`, for example `→ decision 52`. The "Open" sections inside each spec file give more context; they will be replaced by these IDs as questions are decided.

## General and technical
- [x] **Q-GEN-01** ~~ Tech and stack targets: engine, server architecture. The repository is a Flutter/Flame app with an Appwrite backend; confirm this fits a 3D, 100+ player, real-time game. (00)~~ Out of scope for the spec phase (designer, 2026-10-24).

## Map and terrain (10)
- [ ] **Q-MAP-01** Typical map sizes and range of team counts per map.
A: map 10000x50000. Team counts 2 - 5
- [ ] **Q-MAP-02** Craters: can engineers fill them? Do trees and structures regrow? Deformation depth limits?
A: engineers can not fill craters. no regrow. -20 depth limit.
- [ ] **Q-MAP-03** Boats and amphibious units: ~~vehicle type, class or flag?~~ boat is a capability (→ decision 61). Still open: amphibious units, ports or docks, boarding and leaving a boat, can engineers build on water other than bridges?
A: sail is a capability, boat may be a unit with sailing capability. amphibious units are units with sail and earth capabilities, ports or docks do not exist, boarding and leaving a boat is done when boat transport is next to the shore, engineers can build bridges on water and that's all. 
- [x] **Q-MAP-04** Flying units: altitude limits; is flying permanent or can a unit land and take off? → decision 68 (max altitude per map)
- [ ] **Q-MAP-05** Line of sight: ~~height bonus, terrain and weather factors~~ (→ decision 59). Still open: concealment of a target inside a forest, vision of and from flying units, destroyed objects stop blocking.
A: destroyed objets stop blocking sight. concealment is proportional to forest length empeding vision so a flying unit can see target more easily than ground unit.
- [ ] **Q-MAP-06** Floating islands: ladder height limits, stranded ground units, can they host radios, encampments or relics?
A: no ladder height limits, stranded ground units are stranded, radio are units like any others. Relics can not leave floating islands and I don't see how camps could go on floating islands because team HQ won't appear on island. 
- [ ] **Q-MAP-07** Hit points of trees, buildings, walls, bridges.
A: tree as 100 HP, building 500, wall 200 and bridge 200.
- [ ] **Q-MAP-08** Day/night and weather. Weather exists and reduces vision (→ decision 59). Still open: how weather changes (random, scripted, per region), other effects (movement, hit chance), day/night.
A: Weather exists and can change vision (→ decision 59). Weather changes randomly per map there is no day/night, it's always day.
- [ ] **Q-MAP-09** Performance budget for persistent world changes in a 100+ player battle.
A: I don't understand

## Units and progression (20)
- [x] **Q-UNIT-01** Concrete unit list per category with base stats and capabilities. → decisions 60, 61 (stats are placeholders, tuned in playtests)
- [ ] **Q-UNIT-02** Role-specific stats: engineer build speed, medic heal rate, scout spotting range, transport capacity.
A: build is instant but cost AP depending on the HP of the build. heal is instant and x AP heal as much as heal property of the unit. scout have an observe special ation that give temp 30 more sight range. Transport can carry a total weight (each unit has weight) and their is a weight limit for each unit a transport can host.
- [x] **Q-UNIT-03** XP formulas, victoryXp value, kills worth more against higher-level units, anti-farming rules. → decision 77 (victoryXp value moved to Q-UNIT-10)
- [ ] **Q-UNIT-04** Skill trees: ~~respec, cap on nodes per unit, mutually exclusive nodes~~ (→ decision 78). Still open: full tree per unit type (content).
A: just limited evolution of unit stats
- [x] **Q-UNIT-05** Commander: respawn delay, XP loss on death, what the section does while he is dead. → decision 80
- [x] **Q-UNIT-06** Death rules for units carried by transports and for stored units. → decision 81
- [x] **Q-UNIT-07** Catch-up for late joiners inside a war versus veterans with evolved units. → decision 82 (none)
- [x] **Q-UNIT-08** What carries over from one war to the next at account level (cosmetics, ranks, commander slots). → decision 83 (logs, stats, medals, cosmetics only)
- [x] **Q-UNIT-09** How a unit gets its weapons; can a unit carry several weapons? (link between `units.yaml` and `combat.yaml`) → decisions 52, 53
- [ ] **Q-UNIT-10** Value of victoryXp; does it also add to section XP?
A: 1 xp per unit. It counts for section xp.
- [ ] **Q-UNIT-11** Team power (decision 47) uses unit XP: does section XP count too?
A: section xp count

## Relics and victory (30)
- [ ] **Q-REL-01** Name and lore of the relics.
A: big statues of gods of war from different mythologies
- [ ] **Q-REL-02** Capture: duration, AP cost, "near" radius. ~~Is progress lost or kept when an enemy arrives?~~ Lost.
A: 30 min and 50 AP (battle parameters)
- [ ] **Q-REL-03** Who counts as "near": stored units, units in transports, flying units, offline/passive units?
A: every units in capture radius which is a battle parameter with default 30.
- [ ] **Q-REL-04** Push: minimum pushers, ~~AP per second~~ AP per metre (→ decision 66), slope effort formula, extra pushers needed to crush.
A: 10 minimum pusher, one more par unit to crush. slope impact is the same as for other moves
- [ ] **Q-REL-05** Reinforced bridge: cost, build time, hit points; destroyed while a relic is on it?
A: 20 AP, 10 min build time, 400 HP, relic or HQ lost if bridge destroyed
- [ ] **Q-REL-06** Visibility of the 24-hour victory timer (countdown, alerts).
A: Countdown
- [ ] **Q-REL-07** Validate in playtests the fairness of the full timer reset across time zones.
A: NO

## Newcomers, wars and social (40)
- [ ] **Q-SOC-01** Team power formula: weights of active players vs total XP; time window for "active".
A: no notion of active/inactive player in the rules
- [ ] **Q-SOC-02** Team with fewer than 4 guilds; is "new player" a new account or anyone joining a battle; is placement re-evaluated on return?
A: new player is anyone joining. I don't understand "is placement re-evaluated on return"
- [ ] **Q-SOC-03** Guild opt-in for newcomers: can it be left at any time, is there a reward?
A: Can be left any time, no reward or penality
- [ ] **Q-SOC-04** Value of minStartingMoney per war; starting money of a section entering a war.
A: 500 w€
- [ ] **Q-SOC-05** Automatic team creation at each battle: balance by power, keep teams stable, number of teams.
A: balance by power and number of teams is a battle parameter
- [ ] **Q-SOC-06** War result: is there a war winner and how is it decided?
A: No war winner
- [ ] **Q-SOC-07** List and criteria of war medals and game medals (also needed for the HQ manager rule).
A: bronze, silver and gold medals for every kind of actions and kills (units, commander, jeeps, etc...) based on value (exemple: Commander kill bronze medal after killing 5 commanders)
- [ ] **Q-SOC-08** Cosmetics: confirm purely visual (no camouflage or other advantage).
A: purely visual
- [ ] **Q-SOC-09** Joining a war already running (between battles, during a battle).
A: What is the question ?
- [ ] **Q-SOC-10** In-game communication that remains (pings, markers, short orders, chat) and Discord integration level.
A: history is kept
- [ ] **Q-SOC-11** Moderation and blocking tools.
A: To be defined after a few real battles
- [ ] **Q-SOC-12** Getting extra commanders; several wars at the same time; do a player's commanders share money or units?
A: No share between player sections exept for cosmetics bought with option for this. 
- [ ] **Q-SOC-13** Guilds: how the guild commander is chosen, relation with the team commander, guild size, players outside any guild.
A: Guild creator is the chief and he can pass his role to another guild member. He can disband the guild. Player can't leave guild when chief. Guild max size depends on guild level which increase with tatal xp aquired by sections while inside the guild. min guild size is one section. Section can play without being in a guild (all storage is done with HQ) 

## HQ and storage (50)
- [ ] **Q-HQ-01** Can any team unit push the HQ, or only units chosen by the manager?
A: any team unit
- [ ] **Q-HQ-02** HQ hit points and armor.
A: battle parameter : 1000 HP, 10 armor.
- [ ] **Q-HQ-03** Recall delay value; does a recall cost AP or prevent attacking?
A: recall, if it is getting unit out of starage, cost 10 AP and is fully operational. (The AP counter is runing for stored unit until max is reached) 
- [ ] **Q-HQ-04** ~~Storage capacity formula vs commander XP~~ capacity per commander level (→ decision 79, placeholder table); "next to" radius for storing and for blocking deployment.
A: blocking deployment radius: 20. Storing radius 10 or 6 hours
- [ ] **Q-HQ-05** Encampment price and hit points.
A: camp price: 500 w€ and 300 HP, 10 armor.

## Economy (60)
- [ ] **Q-ECO-01** Prices of each troop type, radio and encampment.
A: If not specified it's 100 w€, I will adjust over time in the json files
- [ ] **Q-ECO-02** Money earned per action (hit, kill, construction, heal, HQ hit, HQ destruction).
A: hit 1, kill 5, construction 5, heal 5, HQ hit 10, HQ destruction 100
- [ ] **Q-ECO-03** Transfer fee rates (inside / outside guild).
A: inside 2%, outside 7%
- [ ] **Q-ECO-04** AP cost and build time per construction type.
A: 20 w€ and 10 min. Adjustment later in json file
- [ ] **Q-ECO-05** Can XP be bought? (assumed: earned only)
A: NO
- [ ] **Q-ECO-06** Limits against "build and destroy" money farming by engineers.
A: NO

## Combat and AP (70)
- [x] **Q-CBT-01** AP cost per action: shot, reload, unload, build, heal, push, capture. → decisions 55, 56, 66 (values: placeholders; per-structure build costs in Q-ECO-04)
- [x] **Q-CBT-02** Flying targets: confirm the `airborne_factor` proposal. → decision 57
- [x] **Q-CBT-03** Weapon values: rate of fire, magazine, reload and unload times, ranges; artillery splash and terrain deformation. → decision 69 (placeholders accepted, tuned by simulation and playtests)
- [x] **Q-CBT-04** Reloading: is a partly used magazine kept or lost? → decision 54 (lost; ammo unlimited)
- [x] **Q-CBT-05** Morale: range, recovery over time, formula. → decisions 70, 71
- [x] **Q-CBT-06** 0-HP outcome odds (morale, AP → death / prisoner / defection). → decision 72
- [x] **Q-CBT-07** Prisoners: where they are held, what happens at the end of a battle or war, exchange and ransom flow (who negotiates, who is paid). → decision 73
- [x] **Q-CBT-08** Defectors: can the previous owner recapture them; do defections count in statistics and medals? → decision 74 (statistics; medals with Q-SOC-07)
- [x] **Q-CBT-09** Snowball risk of defections giving evolved units to strong teams. → decision 75 (no extra limit; watch in playtests)
- [x] **Q-CBT-10** Radio: cost, can it be destroyed, starting range and evolution, how scout information is relayed. → decision 76 (price with Q-ECO-01)
- [x] **Q-CBT-11** Artillery and indirect fire: with "fire only at what you see" (decision 59), artillery (1200 m range) needs its own sight. Should artillery be an exception that fires at positions spotted by its section, a scout or a radio? → decision 62
- [x] **Q-CBT-12** Hit-chance formula under orders/AI: weights of attack vs defense, distance, cover, target size and speed. Does partial cover lower hit chance, damage, or both? → decision 65
- [x] **Q-CBT-13** Weapon of a prisoner or a defector: kept, dropped, or taken by the captor? Can a unit fight unarmed (radio, truck have no weapon)? → decision 64
- [x] **Q-CBT-14** Confirm that picking up a dropped weapon costs AP (decision 53) while swapping at storage costs only time (decision 55). → decision 63
- [ ] **Q-CBT-15** Do prisoners use the captor section's storage capacity? Does a captor with full storage still take prisoners?
A: no that's another unlimited storage.
- [ ] **Q-CBT-16** Does morale also affect first-person aim (spread), like `attack` does, to keep both control modes comparable?
A: yes
