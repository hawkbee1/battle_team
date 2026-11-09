# Units and Progression

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`UNIT-NN`).

## 1. Unit categories
commanders, engineers, scouts, artillery, transports, vehicles, soldiers, plus radios and the guild camp (category `encampment`, decision 141). **A medic is a soldier with a heal role** (category `soldier`, decision 60).
- **UNIT-01** **Flying is a capability** (`capabilities: [flying]`), not a unit category: a unit of any suitable category may have it.
- **UNIT-02** **Sail is a capability** (`capabilities: [sail]`): the unit moves on water with the `sail` profile. Without a ground movement class it is a boat; with one it is amphibious. (Decision 86)

## 2. Common stats (every unit)
| Stat | Meaning |
|---|---|
| `hp` | Health. At 0 the unit dies. Permadeath for all units except commanders. |
| `ap_max` | Maximum of the single AP pool: 30 for every unit (decision 167). |
| `ap_per_m` | AP per metre moved on flat ground. Terrain, movement class and slope multiply it (decision 169). |
| `attack` | **Accuracy.** Raises hit chance under orders/AI and tightens spread in first-person aim. Does not change damage. |
| `defense` | **Evasion.** Lowers the chance of being hit. Does not change damage. |
| `move_speed` | Speed when moving, in m/s, close to a real unit's speed: it sets the time per metre. The AP cost is `ap_per_m`. A flying unit's base speed is never above the jeep's, a sailing unit's never above the tank's (decision 174); evolution can then raise it up to 300 % of base, like any stat (decision 178). |
| `vision_range` | Radius of sight before weather, terrain and height modifiers, then limited by line of sight (see map spec). |
| `movement_class` | foot, wheeled or tracked (see map spec). Empty for a boat. |
| `weight` | Used by transports, which carry by weight (decision 91). |
| `hit_box_m` | Hit volume for first-person shots: width, length and height in metres, close to the real unit (decision 183). |
| `armor_type` | Armor type used by the weapon-vs-armor damage table (`data/combat.yaml`). |
| `morale` | 0..100 (see combat spec). |
| `capabilities` | Optional list of extra abilities: `flying`, `sail`. |
| `actions` | What the unit can do besides moving and shooting: `capture`, `push`, `build`, `repair`, `heal`, `observe` (UNIT-38). |

AP recovery is not a unit stat: every unit recovers at the battle's rate, **1 AP per hour** by default (decisions 168, 172; `ap.recovery_per_hour` in `data/battle.yaml`).

Role-specific stats are added per category: medic heal value, scout observe, transport weight limits, radio range, commander aura radius (see section 8). Engineer building: AP + build time per structure (decision 113). Weapon range, splash and terrain deformation belong to the **weapon**, not the unit.

- **UNIT-38** Each unit type lists the **actions it can do** (`actions` in `data/units.yaml`). An order for any other action is refused. A unit never lists an action that costs more AP up front than its `ap_max` (decisions 132, 145).

## 3. Weapons
- **UNIT-03** One weapon slot per unit. Each unit type has a **default weapon** (included in its price) and a list of **allowed** weapon types. (Decision 52)
- **UNIT-04** Swapping happens at storage; killed units drop their weapon for anyone to pick up. Full rules: `specs/70-combat-and-ap.md`, section 4.

## 4. Roster v1 (decision 61)
| Unit | Category | Movement | Armor | Default weapon | Notes |
|---|---|---|---|---|---|
| commander | commander | foot | infantry | rifle | aura, section cap, resurrects |
| soldier | soldier | foot | infantry | rifle | widest weapon list |
| medic | soldier | foot | infantry | rifle | heal role |
| engineer | engineer | foot | infantry | rifle | builds, repairs, explosive charge allowed |
| scout | scout | foot | infantry | rifle | long vision, reports to radios |
| artillery | artillery | tracked | light vehicle | artillery | must unload before moving |
| radio | radio | tracked | structure | none | relays scout info, not transportable |
| jeep | vehicle | wheeled | light vehicle | machine gun | fast |
| tank | vehicle | tracked | heavy vehicle | anti-tank | slow, tough, low evasion |
| truck | transport | wheeled | light vehicle | none | carries units by weight |
| helicopter | vehicle | (flying) | light vehicle | machine gun | flying capability |
| boat | transport | (water) | light vehicle | machine gun | sail capability, carries units by weight |
| encampment (guild camp) | encampment | tracked | structure | none | guild chief's, heals, slow, never stored, outside the cap |

Stats in `data/units.yaml` are placeholders, tuned in playtests.

## 5. XP
Sources (decision 199):
- **UNIT-05** hits and kills; the shot that kills earns both (decision 201). A final blow that takes its target prisoner or turns it earns the kill's XP (decision 223). Hits on an enemy HQ and its destruction earn XP too (decision 224),
- **UNIT-06** role actions (engineers building and repairing, medics healing, scouts spotting enemies),
- **UNIT-07** capturing and objectives,

XP belongs to the unit and persists across the battles of a **war**. A section (and all its units, XP and evolution) is created when the player enters a war and is **lost at the end of the war** (see `specs/40-newcomers-and-social.md`).
- **UNIT-09** **Stronger targets give more XP** (decision 77): hit and kill XP is multiplied by `1 + target XP / attacker XP`, capped at ×3. Both are the XP each unit has earned, spent or not (decision 197).
- **UNIT-10** **Anti-farming**: repeated XP from the same target or the same build spot within a time window shrinks. A build within 10 m of one of the unit's builds in the window is at the same spot (decision 198). Hitting allies gives no XP.
- **UNIT-11** **victoryXp**: every unit of every section in the winning team of a battle gains **1 XP**, which counts toward section XP like any XP. (Decision 92)
- **UNIT-43** **Capture XP is split by AP** (decision 179): when a capture succeeds, its XP (`xp_sources.capture`) is shared among the units that put AP into the capture pot, in proportion to their AP (1 XP per AP with the defaults), including units that died or left the radius since. A lost pot (RELIC-08) pays nothing.
- **UNIT-12** **Team power** = unit XP + section XP of the team (decision 93), with the XP units have earned (decision 197).
- **UNIT-13** No catch-up mechanism for late joiners: placement in the weakest team (decision 47) is the only compensation. (Decision 82)

### Section XP and commander level (decision 79)
- **UNIT-14** A **share of every XP point** a unit earns (20 %, placeholder) is **moved to the section's XP**; the unit keeps the rest.
- **UNIT-15** **Section XP sets the commander level.** The level sets the **section size cap** and the **storage capacity** (UNIT-39, UNIT-40).
- **UNIT-16** Section XP **cannot be spent on stats**, not even the commander's.
- **UNIT-17** Level table: `progression.commander_levels` in `data/units.yaml`; cap rule: `progression.section_size`.
- **UNIT-39** **Section size cap** (decision 127): the number of **active** units (on the field), the commander included. **5** at commander level 1, **+1 every 5 commander levels** (levels 1–5: 5, levels 6–10: 6, ...), up to **16** at level **60**, the maximum (decision 144).
- **UNIT-40** A section owns at most **2 × cap** units (active + stored). Its **storage capacity is 2 × cap**, so all its units always fit in storage. The guild camp and the HQ do not count toward the cap and cannot be stored (decision 127).
- **UNIT-41** A new section starts with its **commander** and its starting money (SOC-15); the player buys his first units with it (decision 128).

## 6. Evolution: skill-point tree
- **UNIT-18** **Each unit spends its own XP on itself**, on the **skill-point tree** of its unit type. This includes the commander, with his own XP and his own tree. (Decision 78)
- **UNIT-19** Nodes can be bought in any order, subject to **prerequisites**.
- **UNIT-20** A node gives a stat bonus, with an XP cost (no abilities, see UNIT-22).
- **UNIT-21** Bought nodes are **permanent** (no respec). **No node excludes another**; the XP cost is the only limit.

- **UNIT-22** Trees give **stat bonuses only**, no abilities. **Every evolved stat is capped at 300 % of its base value** (×3). AP max and AP recovery cannot be evolved. (Decisions 118, 167)
- **UNIT-23** Default tree for every unit type (`data/units.yaml`, `trees`): for each stat, a chain of +10 % steps; step *n* costs 100 × *n* XP and requires step *n* − 1. Some types add their role stats (radio range, aura radius, transport weight, heal).

## 7. Commander
- **UNIT-24** Commander + units = a **section**.
- **UNIT-26** A commander gives bonuses to nearby units of his section (aura).
- **UNIT-27** The commander buys troops with money. A bought unit needs free room in the section and arrives next to the guild camp, or next to the HQ (decision 130).
- **UNIT-28** The commander always resurrects after death (no permadeath for commanders), **at once, without delay**, **in storage** with his section (decisions 80, 125). This stops an inactive player's commander from dying again and again.
- **UNIT-29** **When the commander dies:**
  - he loses a share of his own **unspent XP**, from his earned XP too (decision 207); his **level is never lost**;
  - **all units of his section on the field** (carried ones included) go **instantly to storage**, losing AP and morale; units of other sections his transports carry are set down where they are (decision 206);
  - there is **no 24-hour lock**: the section can deploy again at once, each unit paying 10 AP (decision 125).
  - The XP share, AP loss and morale loss are **battle settings** (`data/battle.yaml`).

## 7b. Between battles of a war (decision 83)
- **UNIT-30** A section keeps everything from one battle to the next: units, XP, evolution, weapons, money, prisoners.
- **UNIT-31** At the start of each battle every unit gets **full AP and HP** and its **morale back to base**, and starts **in storage**, the guild camp included (decision 212).
- **UNIT-32** At the end of the war everything is lost. The game keeps **logs, statistics and medals** for consultation (decisions 49g, 49h); cosmetics are kept (49i).

## 8. Specific unit roles
- **UNIT-33** **Engineer**: builds and repairs bridges, reinforced bridges, ladders, walls, roads, traps. He also repairs every friendly unit except the HQ (decision 139). Earns money for the section by constructing.
- **UNIT-34** **Scout**: shares positions of spotted enemies. Info flows through radios in range to all sections (awareness only: units aim at what they see themselves). Special action **observe**: **+30 m vision range for 30 minutes**, before the weather and terrain factors, 10 AP; the scout cannot move while observing. (Decisions 91, 119, 184)
- **UNIT-35** **Medic**: soldier with a heal role. **Healing is instant**: it costs AP and restores the medic's `heal` value in HP. It works on every friendly unit except the HQ (decision 139). Earns money for the section when healing. (Decision 91)
- **UNIT-36** **Radio**: purchasable by a commander. Gathers info from team scouts in its area (evolvable range) and shares it with all sections. Slow, not transportable.
- **UNIT-37** **Transports** (truck, boat): carry units **by weight**: each unit has a weight; a transport has a total weight capacity and a maximum weight per carried unit (decision 91). Carried units **take a share of every hit** on the transport, computed with their own armor type, and are **ejected with explosion damage** when it is destroyed. (Decision 81) Stored units can never be harmed.
- **UNIT-42** **Guild camp** (encampment, decision 141): a unit of the guild chief's section, outside his cap and never stored except between battles and at its team's elimination (decisions 208, 212). It moves slowly on its own, cannot fly, cannot reach floating islands (decision 88) and heals friendly units. Price, HP and armor: HQ-43.
- **UNIT-44** **Test unit** (decision 239): a unit type for **testing battles only**, with `ap_max` **10,000** and **every action and ability** of the game. It exists only in a battle whose settings allow test units, never in a public war (Q-UNIT-26). It is the exception to decision 167's equal `ap_max`.

## 9. Open questions
See `specs/95-open-questions.md`, section "Units and progression".
