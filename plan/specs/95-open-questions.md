# Open questions (master list)

This is the to-do / done list of the spec phase. Tick a question when it is decided and note the decision number from `00-overview.md`, for example `→ decision 52`. The "Open" sections inside each spec file give more context; they will be replaced by these IDs as questions are decided.

## General and technical
- [x] **Q-GEN-01** ~~ Tech and stack targets: engine, server architecture. The repository is a Flutter/Flame app with an Appwrite backend; confirm this fits a 3D, 100+ player, real-time game. (00)~~ Out of scope for the spec phase (designer, 2026-10-24).

## Map and terrain (10)
- [ ] **Q-MAP-01** Typical map sizes and range of team counts per map.
- [ ] **Q-MAP-02** Craters: can engineers fill them? Do trees and structures regrow? Deformation depth limits?
- [ ] **Q-MAP-03** Boats and amphibious units: ~~vehicle type, class or flag?~~ boat is a capability (→ decision 61). Still open: amphibious units, ports or docks, boarding and leaving a boat, can engineers build on water other than bridges?
- [x] **Q-MAP-04** Flying units: altitude limits; is flying permanent or can a unit land and take off? → decision 68 (max altitude per map)
- [ ] **Q-MAP-05** Line of sight: ~~height bonus, terrain and weather factors~~ (→ decision 59). Still open: concealment of a target inside a forest, vision of and from flying units, destroyed objects stop blocking.
- [ ] **Q-MAP-06** Floating islands: ladder height limits, stranded ground units, can they host radios, encampments or relics?
- [ ] **Q-MAP-07** Hit points of trees, buildings, walls, bridges.
- [ ] **Q-MAP-08** Day/night and weather. Weather exists and reduces vision (→ decision 59). Still open: how weather changes (random, scripted, per region), other effects (movement, hit chance), day/night.
- [ ] **Q-MAP-09** Performance budget for persistent world changes in a 100+ player battle.

## Units and progression (20)
- [x] **Q-UNIT-01** Concrete unit list per category with base stats and capabilities. → decisions 60, 61 (stats are placeholders, tuned in playtests)
- [ ] **Q-UNIT-02** Role-specific stats: engineer build speed, medic heal rate, scout spotting range, transport capacity.
- [x] **Q-UNIT-03** XP formulas, victoryXp value, kills worth more against higher-level units, anti-farming rules. → decision 77 (victoryXp value moved to Q-UNIT-10)
- [ ] **Q-UNIT-04** Skill trees: ~~respec, cap on nodes per unit, mutually exclusive nodes~~ (→ decision 78). Still open: full tree per unit type (content).
- [x] **Q-UNIT-05** Commander: respawn delay, XP loss on death, what the section does while he is dead. → decision 80
- [x] **Q-UNIT-06** Death rules for units carried by transports and for stored units. → decision 81
- [x] **Q-UNIT-07** Catch-up for late joiners inside a war versus veterans with evolved units. → decision 82 (none)
- [x] **Q-UNIT-08** What carries over from one war to the next at account level (cosmetics, ranks, commander slots). → decision 83 (logs, stats, medals, cosmetics only)
- [x] **Q-UNIT-09** How a unit gets its weapons; can a unit carry several weapons? (link between `units.yaml` and `combat.yaml`) → decisions 52, 53
- [ ] **Q-UNIT-10** Value of victoryXp; does it also add to section XP?
- [ ] **Q-UNIT-11** Team power (decision 47) uses unit XP: does section XP count too?

## Relics and victory (30)
- [ ] **Q-REL-01** Name and lore of the relics.
- [ ] **Q-REL-02** Capture: duration, AP cost, "near" radius. ~~Is progress lost or kept when an enemy arrives?~~ Kept (→ decision 67).
- [ ] **Q-REL-03** Who counts as "near": stored units, units in transports, flying units, offline/passive units?
- [ ] **Q-REL-04** Push: minimum pushers, ~~AP per second~~ AP per metre (→ decision 66), slope effort formula, extra pushers needed to crush.
- [ ] **Q-REL-05** Reinforced bridge: cost, build time, hit points; destroyed while a relic is on it?
- [ ] **Q-REL-06** Visibility of the 24-hour victory timer (countdown, alerts).
- [ ] **Q-REL-07** Validate in playtests the fairness of the full timer reset across time zones.

## Newcomers, wars and social (40)
- [ ] **Q-SOC-01** Team power formula: weights of active players vs total XP; time window for "active".
- [ ] **Q-SOC-02** Team with fewer than 4 guilds; is "new player" a new account or anyone joining a battle; is placement re-evaluated on return?
- [ ] **Q-SOC-03** Guild opt-in for newcomers: can it be left at any time, is there a reward?
- [ ] **Q-SOC-04** Value of minStartingMoney per war; starting money of a section entering a war.
- [ ] **Q-SOC-05** Automatic team creation at each battle: balance by power, keep teams stable, number of teams.
- [ ] **Q-SOC-06** War result: is there a war winner and how is it decided?
- [ ] **Q-SOC-07** List and criteria of war medals and game medals (also needed for the HQ manager rule).
- [ ] **Q-SOC-08** Cosmetics: confirm purely visual (no camouflage or other advantage).
- [ ] **Q-SOC-09** Joining a war already running (between battles, during a battle).
- [ ] **Q-SOC-10** In-game communication that remains (pings, markers, short orders, chat) and Discord integration level.
- [ ] **Q-SOC-11** Moderation and blocking tools.
- [ ] **Q-SOC-12** Getting extra commanders; several wars at the same time; do a player's commanders share money or units?
- [ ] **Q-SOC-13** Guilds: how the guild commander is chosen, relation with the team commander, guild size, players outside any guild.

## HQ and storage (50)
- [ ] **Q-HQ-01** Can any team unit push the HQ, or only units chosen by the manager?
- [ ] **Q-HQ-02** HQ hit points and armor.
- [ ] **Q-HQ-03** Recall delay value; does a recall cost AP or prevent attacking?
- [ ] **Q-HQ-04** ~~Storage capacity formula vs commander XP~~ capacity per commander level (→ decision 79, placeholder table); "next to" radius for storing and for blocking deployment.
- [ ] **Q-HQ-05** Encampment price and hit points.

## Economy (60)
- [ ] **Q-ECO-01** Prices of each troop type, radio and encampment.
- [ ] **Q-ECO-02** Money earned per action (hit, kill, construction, heal, HQ hit, HQ destruction).
- [ ] **Q-ECO-03** Transfer fee rates (inside / outside guild).
- [ ] **Q-ECO-04** AP cost and build time per construction type.
- [ ] **Q-ECO-05** Can XP be bought? (assumed: earned only)
- [ ] **Q-ECO-06** Limits against "build and destroy" money farming by engineers.

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
- [ ] **Q-CBT-16** Does morale also affect first-person aim (spread), like `attack` does, to keep both control modes comparable?
