# Map and Terrain

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`MAP-NN`).

## 1. Maps are hand-authored
- **MAP-01** Battle maps are designed by hand (no procedural generation). A battle picks one authored map.
- **MAP-02** A map defines: ground layout, biomes, trees, rivers, lakes, mountains, roads, towns, floating islands, team starting points, and the initial positions of the special units (8 by design; from `victory.relics_to_hold` to fewer than twice as many, decision 218).
- **MAP-03** **Number of teams and map size are battle settings** (chosen when a battle is created, within what the chosen map supports). Each map file declares which team counts it supports and its starting points.
- **MAP-04** Maps are up to **10,000 × 50,000 m**; a battle has **2 to 5 teams**. (Decision 84)
- **MAP-05** Consequence for the build: we need a map format, an authoring workflow and a loader on server and client.

## 2. The world changes during a battle
The world is persistent (battles last days), so changes made to it persist too.

| Change | Source | Persisted |
|---|---|---|
| Built structures (bridges, ladders, walls, roads, traps) | Engineers | Yes, until destroyed |
| Destroyed trees | Weapons | Yes |
| Destroyed buildings (in towns) | Weapons | Yes |
| Terrain deformation (craters) | Weapons, mainly artillery | Yes |

Consequences for the build:
- **MAP-06** The server keeps the authoritative list of world modifications on top of the authored map (a "delta layer").
- **MAP-07** Craters and destroyed objects change cover, pathing and line of sight.
- **MAP-08** Late joiners and returning players must receive the delta layer.
- **MAP-09** Engineers **cannot fill craters**. Destroyed trees and structures **never regrow**. A crater is at most **20 m deep**. (Decision 85)
- **MAP-46** A crater is a **bowl**: at a distance *d* from its centre the ground is `depth × (1 − (d / radius)²)` lower. Where craters overlap, the deepest one counts. Craters dig the ground only, never a floating island. A shot that digs makes a crater as wide as its weapon's splash radius, `craters.depth_per_shot_m` deep (decisions 194, 226).
- **MAP-10** Hit points: tree 100, building 500, wall 200, bridge 200, reinforced bridge 400 (decision 89, `data/terrain.yaml`). An object takes a bombard shot's splash damage like a unit, and a first-person shot that stops on it damages it (decision 226).
- **MAP-40** Objects (trees, buildings, constructions) have an **armor type** for the damage table, `structure` by default (decision 137, `data/terrain.yaml`).
- **MAP-48** Objects stand **only on land**: trees, buildings, walls, traps and roads never on water; bridges only on water, with land at both ends. (Decision 217)

## 3. Movement
Each unit belongs to a **movement class**. Moving costs AP. The AP cost depends on the terrain under the unit, on the movement class, and on the slope.

Movement classes:
- **MAP-11** **foot**: soldiers, engineers, scouts on foot, commanders
- **MAP-12** **wheeled**: light vehicles
- **MAP-13** **tracked**: heavy vehicles, artillery
- **MAP-14** Boats and amphibious units use the `sail` capability (see Water).

Rules:
- **MAP-15** For each (movement class, terrain type) pair the data file gives either a multiplier on the unit's AP per metre (`ap_multiplier`, grass is 1.0; decision 169) or `impassable`.
- **MAP-16** A **slope factor** multiplies the cost. Slope is **signed** (decision 133): going uphill raises the cost, going downhill lowers it, down to a per-class floor. A slope steeper than the per-class maximum, up or down, is impassable.
- **MAP-41** A move from one terrain to another pays **each terrain for the distance on it**, with the slope of the move. (Decision 188)
- **MAP-42** A **bridge deck costs as road** for every unit, relic and HQ. (Decision 189)
- **MAP-44** Intact **buildings and walls stop ground units** (foot, wheeled, tracked), including at the end of a bridge or the top of a ladder. Trees do not. Flying units ignore all of them. (Decision 191)
- **MAP-47** **No cutting corners:** a move never passes between two places when one of them is impassable for it (a wall's corner, a river's bend). (Decision 195)
- **MAP-17** **Flying is a capability, not a movement class.** A unit with the `flying` capability moves with the `flying` profile of the data file: it ignores ground terrain and cannot fly higher than the map's highest terrain point + 10 m (decision 142, `data/terrain.yaml`).
- **MAP-18** **Flying units can land and take off** (decision 68). Both take time, no AP. A landed unit moves with its ground movement class, is hit as a ground target, and can load or unload troops if it carries any. Its altitude limit is given by MAP-17.
- **MAP-19** **Sail is a capability too** (decision 86). A unit with `sail` moves on rivers and lakes with the `sail` profile of the data file. With no ground movement class it is a **boat** (water only); with a ground class as well it is **amphibious**.
- **MAP-20** **Out of AP:** a moving unit is never frozen; once its AP are empty it moves only as fast as its AP come back, at the battle's recovery rate, 1 AP per hour by default (decisions 56, 168, 172; combat spec).
- **MAP-21** The numeric tables live in `data/terrain.yaml`.

## 4. Water (rivers and lakes)
- **MAP-22** Rivers and lakes are **impassable for most units** (foot, wheeled, tracked).
- **MAP-23** They are crossed by **boats**, **amphibious units** (both have `sail`), **flying units**, or over **bridges** built by engineers.
- **MAP-24** There are **no ports or docks**. Units **board or leave a boat when it is next to the shore**. (Decision 86)
- **MAP-25** On water, engineers build **bridges only** (normal or reinforced).

## 5. Line of sight and fog of war
- **MAP-26** **Mountains and buildings block line of sight.** Vision is computed in 3D, so height matters: a sight line runs from the top of the observer's hit volume to the top of the target's, and a hill blocks it where the ground rises above it. A unit carried by a transport sees from it but is not seen on its own. (Decision 235)
- **MAP-27** **Forests conceal** (decision 87): each metre of forest the sight line crosses reduces the observer's effective vision. A flying observer's line crosses less forest, so it sees forest targets more easily than a ground observer.
- **MAP-28** **Destroyed objects stop blocking** sight.
- **MAP-29** Fog of war is shared per section (see overview). A unit's vision contributes to its own section only; radios relay scouts' information to all sections.
- **MAP-49** **What every section knows**, whatever it sees: the relics (position and owner), its own team's HQ, every team's victory countdown (RELIC-16) and the whole delta layer (MAP-08). Enemy HQs and every other section's units, allies included, are known only while one of its units sees them or a scout reports them through a radio. (Decision 232)
- **MAP-30** **A unit fires only at what it sees itself** (decision 59). Shared vision is for awareness, not for aiming.

### Effective vision (decision 59)
Vision is reduced by weather and terrain and extended by height:

`effective vision = (vision_range + observe bonus) × weather factor × terrain factor + height bonus`

The observe bonus is a scout's while it observes (UNIT-34, decision 184), 0 otherwise.

- **MAP-31** **Weather factor**: weather is a state of the battle (clear, rain, fog, snow) that **changes randomly, per map**. Each state has a vision factor. **There is no day/night: it is always day.** (Decision 90)
- **MAP-32** **Terrain factor**: the terrain where the observer stands (for example a forest lowers it).
- **MAP-33** **Height bonus**: an observer standing higher than the target sees farther, up to a cap.
- **MAP-34** Then forest concealment applies, and hard blockers (mountains, buildings) still block.
- **MAP-35** Values in `data/terrain.yaml` (`vision`, `weather`, `vision_factor` per terrain).

## 6. Terrain types
Ground types, trees, roads, towns, rivers, lakes, mountains, floating islands, plus built structures. The exact list and flags (blocks line of sight, gives cover, can be built on) are in `data/terrain.yaml`.

## 7. Floating islands
- **MAP-36** Reachable by **flying units**, or via **bridges or ladders built by engineers** from nearby terrain.
- **MAP-43** **Ladders are for foot units.** Climbing one, up or down, costs the height climbed, priced as flat ground of the terrain at its far end (1 AP per metre for infantry on grass). (Decision 190)
- **MAP-45** A flying unit pays **no AP to go up to an island or down from it**, under the altitude limit (MAP-17). (Decision 192)
- **MAP-37** **No height limit for ladders.** Bridges and ladders can be destroyed; ground units can then be **stranded**. (Decision 88)
- **MAP-38** Radios are units like any other on an island. **Encampments cannot reach islands.**
- **MAP-39** A relic pushed, or the HQ moved, over an island's edge **falls** and lands intact below (decisions 46d, 117, 148). The fall costs no AP. It lands on the ground just past the edge, whatever its terrain, never onto a building or a wall, and its path goes on from there. (Decision 193)

## 8. Open questions
None open. Performance budgets are technical and out of scope for the spec phase.
