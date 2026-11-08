# Open questions (master list)

This is the to-do / done list of the spec phase. Tick a question when it is decided and note the decision number from `00-overview.md`, for example `→ decision 52`. The "Open" sections inside each spec file give more context; they will be replaced by these IDs as questions are decided. Design risks that are not questions are tracked in `specs/96-design-risks.md`.

## General and technical
- [x] **Q-GEN-01** ~~Tech and stack targets: engine, server architecture. The repository is a Flutter/Flame app with an Appwrite backend; confirm this fits a 3D, 100+ player, real-time game. (00)~~ Out of scope for the spec phase (designer, 2026-10-24). Decided in `stack/` (milestone M2, eight records, confirmed 2026-11-01).

- [x] **Q-GEN-02** When the server that runs a battle stops for a while (a crash, an upgrade), does the battle's time go on (decision 3)? → decision 222

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
- [x] **Q-MAP-10** Is slope signed (going downhill cheaper)? → decision 133
- [x] **Q-MAP-11** How is a step between two cells priced? → decision 188
- [x] **Q-MAP-12** What terrain does a bridge deck cost as? → decision 189
- [x] **Q-MAP-13** What does climbing a ladder cost? → decision 190
- [x] **Q-MAP-14** Do intact buildings and walls stop units, as walls stop relics (RELIC-20)? → decision 191
- [x] **Q-MAP-15** Does a flying unit pay to go up to a floating island or down from it? → decision 192
- [x] **Q-MAP-16** A relic or the HQ pushed or moved over a floating island's edge falls (RELIC-22, HQ-48): does the fall cost AP, and where can it land? → decision 193
- [x] **Q-MAP-17** What shape does a crater give the ground, and what if craters overlap? → decision 194
- [x] **Q-MAP-18** Can a unit move diagonally between two cells when one of the two cells it passes between is impassable for it (a wall's corner, a river's bend)? → decision 195
- [x] **Q-MAP-19** How big is the crater a shot digs (MAP-07, MAP-09), and do shots damage objects? → decision 226
- [ ] **Q-MAP-20** How do real places become terrain and objects when a map is made from real data (stack decision 5)? Assumed (M5.20): forests are `forest_floor` with one tree on each cell (forest concealment counts trees); built-up land is `town_street` with its roads painted through, so relics and the HQ cross a town only by road; wetlands are `mud`; rivers and canals are `river`, ponds and lakes `lake`; streams and ditches are left out (a line of water cells no ground unit crosses); hedges and tree rows are a tree on each cell (bocage gives cover, not walls); buildings and walls are objects, never on a road cell.
- [ ] **Q-MAP-21** Which real bridges carry relics and the HQ? Assumed (M5.20): the bridges of motorways, trunk, primary and secondary roads are reinforced bridges, the others ordinary bridges; the author reinforces more by hand where a team's land would be cut off.
- [ ] **Q-MAP-22** Where must a map's attribution be shown to players? The licences of its data ask for it (ODbL for OpenStreetMap, Licence Ouverte for IGN). Assumed (M5.20): each `map.yaml` carries it, and the client shows it wherever it shows the map (M7), for example in the map's credits.
- [ ] **Q-MAP-23** Maps outside France take their heights from the Copernicus DEM (stack decision 5). Assumed (M5.20): its import comes with the first map outside France; the importer reads IGN RGE ALTI only.
- [x] **Q-MAP-24** What does a section know besides what its own units see and what radios relay (decision 21, MAP-29)? → decision 232 (relics, its own HQ, every victory countdown and the delta layer always; enemy HQs and other sections' units only when seen or reported)
- [x] **Q-MAP-25** Vision in 3D (MAP-26): from what height does a unit look, at what height is it seen, and does a unit in a transport see or show? → decision 235 (from the top of the observer's hit volume to the top of the target's, the ground blocks where it rises above the line; a carried unit sees from its transport and is not seen on its own)
- [x] **Q-MAP-26** Where is a moving unit while it moves, for what others see of it? → decision 236 (at its destination from the start of its move; the client shows it moving there; following units along their paths on the host is planned for later, milestone M8)
- [ ] **Q-MAP-27** Does a section know which team a unit it sees belongs to (an ally's or an enemy's), and is the team of each section public? Assumed (M6.7): yes, a unit seen shows its team, as a hit already shows whether it was friendly fire; the host sends each unit it shows with its section's team.

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
- [x] **Q-UNIT-14** Section size cap: does it count the commander, the camp, stored units? How does storage capacity relate to it? → decision 127
- [x] **Q-UNIT-15** Which 4 units does a new section start with (decision 128)? A fixed list, or chosen by the player? → decision 128 (the player buys them with the starting money)
- [x] **Q-UNIT-16** An action that costs more AP than the unit's `ap_max` (a radio ordered to capture). → decision 132 (each unit lists the actions it can do)
- [x] **Q-UNIT-17** Guild camp: owner, cap, storage, movement. → decision 141
- [x] **Q-UNIT-18** Section AI (decision 20): which behaviours (follow commander, hold, patrol...), do units under AI fire on their own, and what do the units of an offline player do (decision 29 says "passive")? → milestone `milestones/m1-ai-and-automation.md`
- [x] **Q-UNIT-19** Commander levels: "+1 every 5 levels" is read as a cap of 6 at level 6, 7 at level 11 (decision 127). `commander_levels` stops at level 5, so the cap never grows yet: section XP thresholds beyond level 5, and is there a maximum level? → decision 144 (max level 60)
- [x] **Q-UNIT-20** Default `actions` per unit type (`data/units.yaml`), set in review: radio and camp neither capture nor push; helicopter and boat capture but do not push; the camp's heals earn money for the chief's section (ECO-18). Confirm or change. → decision 145 (accepted)
- [x] **Q-UNIT-21** Speed caps and evolution: does the cap of decision 174 apply to evolved speeds? → decision 178 (base speeds only; evolution follows the 300 % cap)
- [x] **Q-UNIT-22** Capture XP (`xp_sources.capture`, 50) with a team pot (decision 170): who gets it? → decision 179 (shared by the AP each unit put in, paid on success)
- [x] **Q-UNIT-23** Scout observe (+30 m, decision 119): added to `vision_range` before the weather and terrain factors, or after them? → decision 184 (to `vision_range`)
- [x] **Q-UNIT-24** A commander's final blow that takes its target prisoner or turns it (COMBAT-38): does it earn the kill's XP and money (UNIT-05, ECO-18), or only the hit's? → decision 223 (the kill's XP, not its money)
- [x] **Q-UNIT-25** Do hits on an HQ and its destruction earn XP (UNIT-05), or only money (ECO-18, HQ-04)? → decision 224 (2 XP a hit, 10 for the destruction)

## Relics and victory (30)
- [x] **Q-REL-01** Name and lore of the relics. → decision 96
- [x] **Q-REL-02** Capture: duration, AP cost, radius, progress when an enemy arrives. → decision 97
- [x] **Q-REL-03** Who counts as "near". → decision 97
- [x] **Q-REL-04** Push: minimum pushers, slope, crush rule. → decisions 98, 115
- [x] **Q-REL-05** Reinforced bridge: cost, build time, HP, relic or HQ on a destroyed bridge. → decisions 99, 116
- [x] **Q-REL-06** Visibility of the 24-hour victory timer. → decision 100
- [x] **Q-REL-07** ~~Validate in playtests the fairness of the full timer reset across time zones.~~ Dropped by the designer. → decision 100
- [x] **Q-REL-08** Decision 46d says a relic can fall from a floating island; the answer to Q-MAP-06 says relics cannot leave floating islands. Which one? → decision 117 (they fall)
- [x] **Q-REL-09** Push speed, pushers at 0 AP, crush damage and survivors in the path. → decision 138
- [x] **Q-REL-10** Push speed "5": `data/*.yaml` uses metres and seconds, and 5 m/s is a running soldier's speed, while relics "move very slowly" (RELIC-03). Is it 5 m/s, or another unit (for example 5 m per minute)? → decision 138 (5 m per hour)
- [x] **Q-REL-11** Capture progress: does it belong to the unit or to the team? → decision 140
- [x] **Q-REL-12** Push pot (decision 171): price per metre and slope factor. → decision 175 (10 AP per metre, a `push` profile for ground and slope)
- [x] **Q-REL-13** Control loss (decision 173): what empties a partly filled pot? → decision 176 (a relic's push pot: capture by another team or a fall; a capture pot: an enemy entering the radius)
- [x] **Q-REL-14** Who chooses the path of a pushed relic? → decision 219 (the player whose unit first tries to move it while its pot is empty)
- [x] **Q-REL-15** With a team push pot (decision 171), who are the 10 pushers a relic needs (RELIC-24)? → decision 225 (those that put AP in since the pot was last empty and stay inside the radius)
- [x] **Q-REL-16** Who receives the alert of RELIC-10, and how? → decision 233 (the whole previous owner team: connected players at once, the others when they next connect)

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
- [x] **Q-SOC-10** In-game communication tools. → decision 123
- [x] **Q-SOC-11** Moderation and blocking tools. Deferred: to be defined after a few real battles. → milestone `milestones/m8-revision-after-real-battles.md`
- [x] **Q-SOC-12** Sharing between a player's sections, extra commanders, several wars. → decisions 107, 124
- [x] **Q-SOC-13** Guilds. → decision 108
- [x] **Q-SOC-14** Discord integration: account linking, automatic channels per war/team/guild, a bot posting battle events and statistics? → decision 126 (account linking, channel access by section)
- [x] **Q-SOC-15** Where a newcomer's units appear (decision 33 said the team's starting point). → decision 129
- [x] **Q-SOC-16** Trainee (decision 129): what a trainee can and cannot do, when a section stops being one, whether it applies to every new section (veterans too, decision 101), and whether a player can refuse the guild or leave it. → decision 146 (a member awaiting the chief's acceptance)
- [x] **Q-SOC-17** What happens to a trainee's section when the chief refuses it? → decision 153
- [x] **Q-SOC-18** How does a guild's level rise, and what maximum size does each level give (SOC-47)? → decision 221
- [ ] **Q-SOC-19** When a player reaches the gold threshold of a track, does the player hold the bronze and silver medals of that track too (SOC-26, SOC-29)? Assumed: yes, each tier reached is a medal of its own, so their points add up (1 + 3 + 10). War and game medals use the same thresholds: war medals count what the player did in that war, game medals what the player did in every war.

## HQ and storage (50)
- [x] **Q-HQ-01** Can any team unit push the HQ? → decision 109 (yes)
- [x] **Q-HQ-02** HQ hit points and armor. → decisions 109, 114
- [x] **Q-HQ-03** Recall delay value; does a recall cost AP or prevent attacking? → decision 110
- [x] **Q-HQ-04** Storage capacity per level (decision 79); radii for storing and blocking deployment. → decision 110
- [x] **Q-HQ-05** Encampment price, HP and armor. → decisions 111, 114
- [x] **Q-HQ-06** Does the 24-hour lock (decision 120) also start when a section is stored because its commander died (decision 80)? If yes, every commander death would block the section for 24 hours. → decision 125 (no; the commander resurrects in storage)
- [x] **Q-HQ-07** Where a bought unit arrives, and the room it needs. → decision 130
- [x] **Q-HQ-08** Is the arrival of new units at the camp or the HQ blocked by an enemy within 20 m, like deployment (HQ-36)? → decision 147 (yes)
- [x] **Q-HQ-09** Can a pushed HQ go over the edge of a floating island and fall, like a relic (RELIC-22)? → decision 148 (yes)
- [x] **Q-HQ-10** The HQ is not pushed: how does it move? → decision 177 (own AP, 0.2 AP per metre with the `push` profile, 5 m per hour; a unit in its path ends the order)
- [x] **Q-HQ-11** A team left empty at the battle start has no HQ manager (HQ-07): who manages it once a newcomer joins? → decision 220 (the first player to log in, then any higher-ranking player who logs in)
- [x] **Q-HQ-12** Decision 220: does a player who logs in take the role from a manager the role was delegated to, and who keeps it on an exact tie? → decision 227 (only if they would take it without the delegation)

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
- [x] **Q-CBT-18** Can friendly fire take prisoners or cause defections? → decision 131
- [x] **Q-CBT-19** Can an enemy commander, or a guild camp, be taken prisoner or defect when a commander deals the final blow? → decision 149 (no)
- [x] **Q-CBT-20** Firing cycle of 1-round weapons: `rate_of_fire_rpm` applies "while the magazine is not empty". Is the time between two artillery shots the reload time (10 s), the rate of fire (15 s), or both added (25 s)? → decision 150 (the reload time)
- [x] **Q-CBT-21** Weapon inventory: where are bought weapons and swapped-out weapons kept, and is there a limit? → decision 151 (in storage until a unit takes one)
- [x] **Q-CBT-22** Weapon swap time. → decision 134
- [x] **Q-CBT-23** Full cover (factor 0) versus the 5 % minimum hit chance. → decision 135
- [x] **Q-CBT-24** Indirect fire: what a hit on a ground position means, and whether splash victims roll separately. → decision 136
- [x] **Q-CBT-25** Is the engineer's explosive charge a bombard attack (it has a 4 m splash in `data/combat.yaml`)? Where does a missed bombard shot land? → decision 152 (yes; the explosive charge never misses)
- [x] **Q-CBT-28** Where does a missed artillery shot land? Friendly fire is on (COMBAT-34). → decision 154
- [x] **Q-CBT-26** Armor type of terrain objects; base of the ejection damage. → decision 137
- [x] **Q-CBT-27** Heal and repair targets. → decision 139
- [x] **Q-CBT-29** Does a capture pot or a push pot keep its AP, or does it empty over time? → decision 173 (it stays until used up or control is lost)
- [x] **Q-CBT-30** Does the 30-minute capture start when the pot is full, or does it run while the pot fills? → decision 173 (when full)
- [x] **Q-CBT-31** Does `move_speed` drop on rough ground (forest, mud), or does only the AP cost change? → decision 180 (only the AP cost)
- [x] **Q-CBT-32** `ap_per_m` of the units the designer did not name. → decision 181 (placeholders accepted)
- [x] **Q-CBT-33** Infantry pace, radio and guild camp speeds. → decision 182 (infantry runs; radio 5 m/s, guild camp 1 m/s)
- [x] **Q-CBT-34** First-person shots: projectile speed or instant hit, and the hit volume of each unit type. → decision 183 (a speed per weapon; `hit_box_m` per unit and for the HQ)
- [x] **Q-CBT-35** Crushing with 10 + *n* pushers and more than *n* units in the path: does the relic crush *n* of them and stop at the next, or stop at once? → decision 185 (crushes the first *n* it meets, stops at the next)
- [x] **Q-CBT-36** Friendly fire and the own HQ: COMBAT-34 hurts allies, HQ-16 says enemy units damage the HQ. Does own fire damage the own HQ? → decision 186 (yes)
- [x] **Q-CBT-37** Is a weapon taken from storage or picked up loaded? → decision 187 (unloaded; a new unit's default weapon comes loaded)
- [x] **Q-CBT-38** What does a section learn when one of its units is hit by a shooter it does not see? → decision 234 (the hit and its damage, not the shooter nor where the shot came from)
- [x] **Q-CBT-39** What does a section learn of a shot whose shooter or target it does not see, when neither is its own unit? → decision 237 (no clue about what it does not see: an unseen shooter's hit shows the hit and damage only; a seen shooter at an unseen target shows as firing, outcome unknown; an unseen dropped weapon is not shown)

## Section AI and automation (80)
- [x] **Q-AI-01** ~~A player unit with no order: stays still, or follows a simple behaviour?~~ Dropped by the designer (2026-10-31).
- [x] **Q-AI-02** ~~Units of an offline player: same as Q-AI-01, or different?~~ Dropped by the designer (2026-10-31).
- [x] **Q-AI-03** AI agents through the API: same rules and limits as a human player; only the call rate is limited. → decision 157
- [x] **Q-AI-04** API keys: one per account. → decision 158
- [x] **Q-AI-05** Server-managed sections: they look the same as other sections; their purpose stays out of the specs. → decision 159
- [x] **Q-AI-06** Server-managed sections: fixed chance per check, checked every 30 minutes. → decision 160
- [x] **Q-AI-07** Server-managed units: besides the chance-based fire, can they move, hold, heal or capture? → decision 163 (same capabilities as a normal section)
- [x] **Q-AI-08** Hit rule of a server-managed shot: the hit chance of COMBAT-15, or another rule? → decision 164 (same rules as a normal unit)
- [x] **Q-AI-09** What chance does a server-managed unit fire with at each check (decision 160)? → decision 196
- [x] **Q-AI-10** At a server-managed unit's fire check (AI-07), which enemy does it fire at? → decision 228 (the nearest enemy unit it can fire at)
- [x] **Q-AI-11** When is a server-managed unit's first fire check (AI-07)? → decision 229 (30 minutes after the battle starts, then every 30 minutes for all units together)
- [ ] **Q-AI-12** Does an AI agent that connects to a battle with the account's API key log the player in to it (HQ-07: the first player of a team to log in manages its HQ, and a higher-ranking one takes the role when he logs in)? Assumed (M6.5): yes when it opens a socket, since the agent acts for the account (decisions 157, 158); a single HTTPS command is not a log-in.
