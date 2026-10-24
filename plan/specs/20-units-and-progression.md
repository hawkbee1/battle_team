# Units and Progression (working draft)

Status: draft. Numbers are placeholders. Data lives in `data/units.yaml`.

## 1. Unit categories
commanders, engineers, scouts, artillery, transports, vehicles, soldiers. Plus medics and radios (decided during the economy and vision discussions). **Flying is a capability** (`capabilities: [flying]`), not a unit category: a unit of any suitable category may have it. Amphibious units and boats are needed for water crossing (to be placed in a category).

## 2. Common stats (every unit)
| Stat | Meaning |
|---|---|
| `hp` | Health. At 0 the unit dies. Permadeath for all units except commanders. |
| `ap_max` | Maximum of the single AP pool. |
| `ap_regen` | AP regenerated per second, up to `ap_max`. |
| `attack` | Damage dealt by the unit's attacks. |
| `defense` | Armor / damage reduction. |
| `move_speed` | Speed when moving (moving costs AP). |
| `vision_range` | Radius of sight, then limited by line of sight (mountains, buildings and trees block it). |
| `movement_class` | foot, wheeled or tracked (see map spec). |
| `capabilities` | Optional list of extra abilities. `flying`: the unit flies (flying movement profile, hit as a flying target). |

Role-specific stats are added per category (examples to be defined: artillery range and splash, engineer build speed, medic heal rate, scout spotting range, transport capacity, radio range, commander aura radius and section size cap).

## 3. XP
Sources (all four were chosen):
- hits and kills,
- role actions (engineers building and repairing, medics healing, scouts spotting enemies),
- capturing and objectives,
- time survived near the commander.

XP belongs to the unit and persists across the battles of a **war**. A section (and all its units, XP and evolution) is created when the player enters a war and is **lost at the end of the war** (see `specs/40-newcomers-and-social.md`).
- **victoryXp**: every unit of every section in the winning team of a battle gains `victoryXp`.
- A unit's XP value is also its **power score**, used to compute team power.
Open: XP formulas, value of victoryXp, whether kills are worth more against higher-level units, anti-farming rules.

## 4. Evolution: skill-point tree
- XP is spent on a **skill-point tree**: nodes can be bought in any order, subject to **prerequisites**.
- Each unit type has its own predetermined tree.
- A node gives either a stat bonus or an ability, with an XP cost.
- Open: can points be respecced? Is there a cap on total nodes per unit? Do some nodes exclude others? How do evolved stats interact with the catch-up problem for new players?

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

## 5. Commander
- Commander + units = a **section**.
- Section size cap grows with the commander's XP.
- A commander gives bonuses to nearby units of his section (aura).
- The commander buys troops with money.
- The commander always resurrects at the HQ after death (no permadeath for commanders).
- Open: respawn delay, XP loss on death, what happens to the section when the commander is dead.

## 6. Specific unit roles
- **Engineer**: builds and repairs bridges, ladders, walls, roads, traps. Earns money for the section by constructing.
- **Scout**: shares positions of spotted enemies. Info flows through radios in range to all sections.
- **Medic**: heals other units and earns money for the section when healing.
- **Radio**: purchasable by a commander. Gathers info from team scouts in its area (evolvable range) and shares it with all sections. Slow, not transportable.
- **Artillery, transports, vehicles, soldiers**: to be detailed (weapon types, ranges, capacity).

## 7. Open questions
- Concrete unit list per category with base stats.
- Troop costs (money) and purchase flow (where do bought units appear? at HQ?).
- Death rules for units carried by transports and for units that are stored.
- Balance: effect of evolved units on late joiners inside a war (units reset at the end of each war).
- Does anything carry over from one war to the next at account level (cosmetics, ranks, commander slots)?
