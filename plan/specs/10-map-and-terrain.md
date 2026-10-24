# Map and Terrain (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers are placeholders until tuned.

## 1. Maps are hand-authored
- Battle maps are designed by hand (no procedural generation). A battle picks one authored map.
- A map defines: ground layout, biomes, trees, rivers, lakes, mountains, roads, towns, floating islands, team starting points, and the initial positions of the 8 special units.
- **Number of teams and map size are battle settings** (chosen when a battle is created, within what the chosen map supports). Each map file declares which team counts it supports and its starting points.
- Consequence for the build: we need a map format, an authoring workflow and a loader on server and client.

## 2. The world changes during a battle
The world is persistent (battles last days), so changes made to it persist too.

| Change | Source | Persisted |
|---|---|---|
| Built structures (bridges, ladders, walls, roads, traps) | Engineers | Yes, until destroyed |
| Destroyed trees | Weapons | Yes |
| Destroyed buildings (in towns) | Weapons | Yes |
| Terrain deformation (craters) | Weapons, mainly artillery | Yes |

Consequences for the build:
- The server keeps the authoritative list of world modifications on top of the authored map (a "delta layer").
- Craters and destroyed objects change cover, pathing and line of sight.
- Late joiners and returning players must receive the delta layer.
- Open: can craters be repaired/filled by engineers? Do structures and trees regrow? Limits on deformation depth?

## 3. Movement
Each unit belongs to a **movement class**. Moving costs AP. The AP cost depends on the terrain under the unit, on the movement class, and on the slope.

Movement classes:
- **foot**: soldiers, engineers, scouts on foot, commanders
- **wheeled**: light vehicles
- **tracked**: heavy vehicles, artillery
- Amphibious units and boats exist (see Water) and need a class or a flag: to be defined with the unit list.

Rules:
- For each (movement class, terrain type) pair the data file gives either an AP cost per metre or `impassable`.
- A **slope factor** multiplies the cost: the steeper the slope, the higher the cost; above a per-class maximum slope the terrain is impassable.
- **Flying is a capability, not a movement class.** A unit with the `flying` capability moves with the `flying` profile of the data file: it ignores ground terrain but may have altitude limits (open).
- Open: is flying permanent for such a unit, or can it land and take off (and then move with its ground class)? (Q-MAP-04)
- **Boat is a capability too.** A unit with the `boat` capability moves only on rivers and lakes, with the `boat` profile of the data file. (Decision 61)
- **Out of AP:** a moving unit is never frozen; once its AP are empty it moves only as fast as its regen allows (decision 56, combat spec).
- The numeric tables live in `data/terrain.yaml`.

## 4. Water (rivers and lakes)
- Rivers and lakes are **impassable for most units** (foot, wheeled, tracked).
- They are crossed by **boats**, **amphibious units**, **flying units**, or over **bridges** built by engineers.
- Roster v1 has a **boat** unit (transport category, boat capability, carries foot units).
- Open: amphibious units, ports/docks, how foot units board and leave a boat, can engineers build on water other than bridges? (Q-MAP-03)

## 5. Line of sight and fog of war
- **Mountains, buildings and trees block line of sight.** Vision is computed in 3D, so height matters.
- Fog of war is shared per section (see overview). A unit's vision contributes to its own section only; radios relay scouts' information to all sections.
- **A unit fires only at what it sees itself** (decision 59). Shared vision is for awareness, not for aiming.

### Effective vision (decision 59)
Vision is reduced by weather and terrain and extended by height:

`effective vision = vision_range × weather factor × terrain factor + height bonus`

- **Weather factor**: weather is a state of the battle that changes over time (clear, rain, fog, snow). Each state has a vision factor.
- **Terrain factor**: the terrain where the observer stands (for example a forest lowers it).
- **Height bonus**: an observer standing higher than the target sees farther, up to a cap.
- Then hard line-of-sight blockers (mountains, buildings, trees) still block.
- Values in `data/terrain.yaml` (`vision`, `weather`, `vision_factor` per terrain).
- Open (Q-MAP-05): does a target inside a forest get concealment, vision of and from flying units, destroyed trees/buildings stop blocking.

## 6. Terrain types (draft list)
Ground types, trees, roads, towns, rivers, lakes, mountains, floating islands, plus built structures. The exact list and flags (blocks line of sight, gives cover, can be built on) are in `data/terrain.yaml`.

## 7. Floating islands
- Reachable by **flying units**, or via **bridges or ladders built by engineers** from nearby terrain.
- Open: height limits for ladders, whether bridges can be destroyed, whether ground units can be stranded on an island, whether floating islands can host radios, encampments or special units.

## 8. Open questions
- Typical map sizes and the range of team counts per map (to be written by the map author).
- Destructibility details: hit points for trees, buildings, walls, bridges.
- Weather exists and reduces vision (decision 59). Still open: how weather changes (random, scripted per map, per region), other effects (movement, hit chance), and day/night. (Q-MAP-08)
- Performance budget for persistent craters and modifications on a 100+ player battle.
