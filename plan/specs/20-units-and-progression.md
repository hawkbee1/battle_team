# Units and Progression (working draft)

Status: draft. Numbers are placeholders. Data lives in `data/units.yaml`.

## 1. Unit categories
commanders, engineers, scouts, artillery, transports, vehicles, soldiers, plus radios. **A medic is a soldier with a heal role** (category `soldier`, decision 60).
- **Flying is a capability** (`capabilities: [flying]`), not a unit category: a unit of any suitable category may have it.
- **Boat is a capability** (`capabilities: [boat]`): the unit moves only on water, with the `boat` movement profile. Amphibious units (land and water) are still open (Q-MAP-03).

## 2. Common stats (every unit)
| Stat | Meaning |
|---|---|
| `hp` | Health. At 0 the unit dies. Permadeath for all units except commanders. |
| `ap_max` | Maximum of the single AP pool. |
| `ap_regen` | AP regenerated per second, up to `ap_max`. |
| `attack` | **Accuracy.** Raises hit chance under orders/AI and tightens spread in first-person aim. Does not change damage. |
| `defense` | **Evasion.** Lowers the chance of being hit. Does not change damage. |
| `move_speed` | Speed when moving (moving costs AP). |
| `vision_range` | Radius of sight before weather, terrain and height modifiers, then limited by line of sight (see map spec). |
| `movement_class` | foot, wheeled or tracked (see map spec). Empty for a boat. |
| `armor_type` | Armor type used by the weapon-vs-armor damage table (`data/combat.yaml`). |
| `morale` | 0..100 (see combat spec). |
| `capabilities` | Optional list of extra abilities: `flying`, `boat`. |

Role-specific stats are added per category (examples to be defined: engineer build speed, medic heal rate, scout spotting range, transport capacity, radio range, commander aura radius and section size cap). Weapon range, splash and terrain deformation belong to the **weapon**, not the unit.

## 3. Weapons
- One weapon slot per unit. Each unit type has a **default weapon** (included in its price) and a list of **allowed** weapon types. (Decision 52)
- Swapping happens at storage; killed units drop their weapon for anyone to pick up. Full rules: `specs/70-combat-and-ap.md`, section 4.

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
| truck | transport | wheeled | light vehicle | none | carries foot units |
| helicopter | vehicle | (flying) | light vehicle | machine gun | flying capability |
| boat | transport | (water) | light vehicle | machine gun | boat capability, carries foot units |

Stats in `data/units.yaml` are placeholders, tuned in playtests.

## 5. XP
Sources (all four were chosen):
- hits and kills,
- role actions (engineers building and repairing, medics healing, scouts spotting enemies),
- capturing and objectives,
- time survived near the commander.

XP belongs to the unit and persists across the battles of a **war**. A section (and all its units, XP and evolution) is created when the player enters a war and is **lost at the end of the war** (see `specs/40-newcomers-and-social.md`).
- **Stronger targets give more XP** (decision 77): hit and kill XP is multiplied by `1 + target XP / attacker XP`, capped at ×3.
- **Anti-farming**: repeated XP from the same target or the same build spot within a time window shrinks. Hitting allies gives no XP.
- **victoryXp**: every unit of every section in the winning team of a battle gains `victoryXp` (value: Q-UNIT-10).
- A unit's XP value is also its **power score**, used to compute team power.
- No catch-up mechanism for late joiners: placement in the weakest team (decision 47) is the only compensation. (Decision 82)

### Section XP and commander level (decision 79)
- A **share of every XP point** a unit earns (20 %, placeholder) is **moved to the section's XP**; the unit keeps the rest.
- **Section XP sets the commander level.** The level sets the **section size cap** and the **storage capacity**.
- Section XP **cannot be spent on stats**, not even the commander's.
- Level table: `progression.commander_levels` in `data/units.yaml`.

## 6. Evolution: skill-point tree
- **Each unit spends its own XP on itself**, on the **skill-point tree** of its unit type. This includes the commander, with his own XP and his own tree. (Decision 78)
- Nodes can be bought in any order, subject to **prerequisites**.
- A node gives either a stat bonus or an ability, with an XP cost.
- Bought nodes are **permanent** (no respec). **No node excludes another**; the XP cost is the only limit.

Format sketch (in `data/units.yaml`):
```yaml
trees:
  soldier:
    nodes:
      tough_1:   { cost: 100, requires: [],          effects: { hp: +10 } }
      tough_2:   { cost: 250, requires: [tough_1],   effects: { hp: +20 } }
      sprint:    { cost: 200, requires: [],          effects: { move_speed: +10% } }
      sharp_1:   { cost: 150, requires: [],          effects: { attack: +5 } }
      breacher:  { cost: 400, requires: [sharp_1, tough_1], ability: breach_wall }
```

## 7. Commander
- Commander + units = a **section**.
- Section size cap and storage capacity grow with the **commander level**, which comes from section XP.
- A commander gives bonuses to nearby units of his section (aura).
- The commander buys troops with money.
- The commander always resurrects at the HQ after death (no permadeath for commanders), **at once, without delay**. (Decision 80)
- **When the commander dies:**
  - he loses a share of his own **unspent XP**; his **level is never lost**;
  - **all units of his section on the field** (carried ones included) go **instantly to storage**, losing AP and morale.
  - The XP share, AP loss and morale loss are **battle settings** (`data/battle.yaml`).

## 7b. Between battles of a war (decision 83)
- A section keeps everything from one battle to the next: units, XP, evolution, weapons, money, prisoners.
- At the start of each battle every unit gets **full AP and HP** and its **morale back to base**.
- At the end of the war everything is lost. The game keeps **logs, statistics and medals** for consultation (decisions 49g, 49h); cosmetics are kept (49i).

## 8. Specific unit roles
- **Engineer**: builds and repairs bridges, reinforced bridges, ladders, walls, roads, traps. Earns money for the section by constructing.
- **Scout**: shares positions of spotted enemies. Info flows through radios in range to all sections (awareness only: units aim at what they see themselves).
- **Medic**: soldier with a heal role. Heals other units and earns money for the section when healing.
- **Radio**: purchasable by a commander. Gathers info from team scouts in its area (evolvable range) and shares it with all sections. Slow, not transportable.
- **Transports** (truck, boat): carry foot units. Carried units **take a share of every hit** on the transport, computed with their own armor type, and are **ejected with explosion damage** when it is destroyed. (Decision 81) Stored units can never be harmed.

## 9. Open questions
See `specs/95-open-questions.md`, section "Units and progression".
