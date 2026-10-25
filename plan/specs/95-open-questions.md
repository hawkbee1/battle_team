# Open questions (master list)

This is the to-do / done list of the spec phase. Tick a question when it is decided and note the decision number from `00-overview.md`, for example `→ decision 52`. The "Open" sections inside each spec file give more context; they will be replaced by these IDs as questions are decided.

## General and technical
- [x] **Q-GEN-01** ~~ Tech and stack targets: engine, server architecture. The repository is a Flutter/Flame app with an Appwrite backend; confirm this fits a 3D, 100+ player, real-time game. (00)~~ Out of scope for the spec phase (designer, 2026-10-24).

## Map and terrain (10)
- [x] **Q-MAP-01** Typical map sizes and range of team counts per map. → decision 84
- [x] **Q-MAP-02** Craters: can engineers fill them? Do trees and structures regrow? Deformation depth limits? → decision 85
- [x] **Q-MAP-03** Boats and amphibious units, ports or docks, boarding, building on water. → decision 86
- [x] **Q-MAP-04** Flying units: altitude limits; is flying permanent or can a unit land and take off? → decision 68 (max altitude per map)
- [x] **Q-MAP-05** Line of sight: concealment inside forests, vision of flying units, destroyed objects stop blocking. → decisions 59, 87
- [x] **Q-MAP-06** Floating islands: ladder height limits, stranded ground units, radios, encampments, relics. → decisions 88, 117
- [x] **Q-MAP-07** Hit points of trees, buildings, walls, bridges. → decision 89
- [x] **Q-MAP-08** Day/night and weather. → decisions 59, 90
- [x] **Q-MAP-09** ~~Performance budget for persistent world changes in a 100+ player battle.~~ Technical: out of scope for the spec phase, like Q-GEN-01.

## Units and progression (20)
- [x] **Q-UNIT-01** Concrete unit list per category with base stats and capabilities. → decisions 60, 61 (stats are placeholders, tuned in playtests)
- [x] **Q-UNIT-02** Role-specific stats. → decisions 91, 113, 119
- [x] **Q-UNIT-03** XP formulas, kills worth more against higher-level units, anti-farming rules. → decision 77
- [x] **Q-UNIT-04** Skill trees: respec, cap, exclusive nodes, content. → decisions 78, 118 (default stat tree for every unit type in `data/units.yaml`)
- [x] **Q-UNIT-05** Commander: respawn delay, XP loss on death, what the section does while he is dead. → decision 80
- [x] **Q-UNIT-06** Death rules for units carried by transports and for stored units. → decision 81
- [x] **Q-UNIT-07** Catch-up for late joiners inside a war versus veterans with evolved units. → decision 82 (none)
- [x] **Q-UNIT-08** What carries over from one war to the next at account level. → decision 83 (logs, stats, medals, cosmetics only)
- [x] **Q-UNIT-09** How a unit gets its weapons; can a unit carry several weapons? → decisions 52, 53
- [x] **Q-UNIT-10** Value of victoryXp; does it also add to section XP? → decision 92
- [x] **Q-UNIT-11** Team power: does section XP count too? → decision 93
- [x] **Q-UNIT-12** "Just limited evolution of unit stats": trees give stat bonuses only (no abilities)? Is each stat capped (e.g. at most +50 % over base)? → decision 118 (stats only, cap 300 % of base)
- [x] **Q-UNIT-13** Scout observe: +30 m or +30 %? Duration, AP cost, can the scout move while observing? → decision 119

## Relics and victory (30)
- [x] **Q-REL-01** Name and lore of the relics. → decision 96
- [x] **Q-REL-02** Capture: duration, AP cost, radius, progress when an enemy arrives. → decision 97
- [x] **Q-REL-03** Who counts as "near". → decision 97
- [x] **Q-REL-04** Push: minimum pushers, slope, crush rule. → decisions 98, 115
- [x] **Q-REL-05** Reinforced bridge: cost, build time, HP, relic or HQ on a destroyed bridge. → decisions 99, 116
- [x] **Q-REL-06** Visibility of the 24-hour victory timer. → decision 100
- [x] **Q-REL-07** ~~Validate in playtests the fairness of the full timer reset across time zones.~~ Dropped by the designer. → decision 100
- [x] **Q-REL-08** Decision 46d says a relic can fall from a floating island; the answer to Q-MAP-06 says relics cannot leave floating islands. Which one? → decision 117 (they fall)

## Newcomers, wars and social (40)
- [x] **Q-SOC-01** Team power formula. → decision 93 (no notion of active players)
- [x] **Q-SOC-02** New player, fewer than 4 guilds, return to a battle. → decisions 101, 120 (a player never leaves a battle)
- [x] **Q-SOC-03** Guild opt-in for newcomers: can it be left at any time, is there a reward? → decision 101
- [x] **Q-SOC-04** Value of minStartingMoney; starting money of a section entering a war. → decision 102
- [x] **Q-SOC-05** Automatic team creation at each battle. → decision 103
- [x] **Q-SOC-06** War result: is there a war winner? → decision 104 (no)
- [x] **Q-SOC-07** Medals: tiers, thresholds, points. → decisions 105, 121
- [x] **Q-SOC-08** Cosmetics: purely visual. → decision 106
- [x] **Q-SOC-09** Can a player enter a war after its first battle has started? If yes, can he enter a battle already running, or only from the next battle? → decision 122
- [x] **Q-SOC-10** In-game communication tools. → decision 123 (pings and markers only, history kept; the rest on Discord)
- [ ] **Q-SOC-11** Moderation and blocking tools. Deferred: to be defined after a few real battles.
- [x] **Q-SOC-12** Sharing between a player's sections, extra commanders, several wars. → decisions 107, 124
- [x] **Q-SOC-13** Guilds. → decision 108
- [x] **Q-SOC-14** Discord integration: account linking, automatic channels per war/team/guild, a bot posting battle events and statistics? → decision 126 (account linking, channel access by section)

## HQ and storage (50)
- [x] **Q-HQ-01** Can any team unit push the HQ? → decision 109 (yes)
- [x] **Q-HQ-02** HQ hit points and armor. → decisions 109, 114
- [x] **Q-HQ-03** Recall delay value; does a recall cost AP or prevent attacking? → decision 110
- [x] **Q-HQ-04** Storage capacity per level (decision 79); radii for storing and blocking deployment. → decision 110
- [x] **Q-HQ-05** Encampment price, HP and armor. → decisions 111, 114
- [x] **Q-HQ-06** Does the 24-hour lock (decision 120) also start when a section is stored because its commander died (decision 80)? If yes, every commander death would block the section for 24 hours. → decision 125 (no; the commander resurrects in storage)

## Economy (60)
- [x] **Q-ECO-01** Prices of each troop type, radio and encampment. → decision 112 (default 100 w€)
- [x] **Q-ECO-02** Money earned per action. → decision 112
- [x] **Q-ECO-03** Transfer fee rates. → decision 112
- [x] **Q-ECO-04** Constructions: the answers say "build is instant, AP depends on the HP of the build" (Q-UNIT-02), "20 w€ and 10 min" (Q-ECO-04) and "20 AP, 10 min" for the reinforced bridge. Decision 25d says constructions cost no money. Which is it? → decision 113 (AP + build time, no money)
- [x] **Q-ECO-05** Can XP be bought? → decision 112 (no)
- [x] **Q-ECO-06** Limits against build-and-destroy farming. → decision 112 (none)

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
- [x] **Q-CBT-15** Do prisoners use the captor section's storage capacity? Does a captor with full storage still take prisoners? → decision 94
- [x] **Q-CBT-16** Does morale also affect first-person aim (spread), like `attack` does, to keep both control modes comparable? → decision 95
- [x] **Q-CBT-17** HQ and encampment "10 armor": armor is a type in the damage table (decision 57), not a number. Is 10 a flat damage reduction per hit for structures, an evasion (`defense`) value, or something else? → decision 114 (no numeric armor)
