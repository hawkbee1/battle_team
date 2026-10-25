# Map and Terrain (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers are placeholders until tuned.

## 1. Maps are hand-authored
- Battle maps are designed by hand (no procedural generation). A battle picks one authored map.
- A map defines: ground layout, biomes, trees, rivers, lakes, mountains, roads, towns, floating islands, team starting points, and the initial positions of the 8 special units.
- **Number of teams and map size are battle settings** (chosen when a battle is created, within what the chosen map supports). Each map file declares which team counts it supports and its starting points.
- Maps are up to **10,000 × 50,000 m**; a battle has **2 to 5 teams**. (Decision 84)
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
- Engineers **cannot fill craters**. Destroyed trees and structures **never regrow**. A crater is at most **20 m deep**. (Decision 85)
- Hit points: tree 100, building 500, wall 200, bridge 200, reinforced bridge 400 (decision 89, `data/terrain.yaml`).

## 3. Movement
Each unit belongs to a **movement class**. Moving costs AP. The AP cost depends on the terrain under the unit, on the movement class, and on the slope.

Movement classes:
- **foot**: soldiers, engineers, scouts on foot, commanders
- **wheeled**: light vehicles
- **tracked**: heavy vehicles, artillery
- Boats and amphibious units use the `sail` capability (see Water).

Rules:
- For each (movement class, terrain type) pair the data file gives either an AP cost per metre or `impassable`.
- A **slope factor** multiplies the cost: the steeper the slope, the higher the cost; above a per-class maximum slope the terrain is impassable.
- **Flying is a capability, not a movement class.** A unit with the `flying` capability moves with the `flying` profile of the data file: it ignores ground terrain but may have altitude limits (open).
- **Flying units can land and take off** (decision 68). Both take time, no AP. A landed unit moves with its ground movement class, is hit as a ground target, and can load or unload troops if it carries any. Each map sets a **maximum flying altitude**.
- **Sail is a capability too** (decision 86). A unit with `sail` moves on rivers and lakes with the `sail` profile of the data file. With no ground movement class it is a **boat** (water only); with a ground class as well it is **amphibious**.
- **Out of AP:** a moving unit is never frozen; once its AP are empty it moves only as fast as its regen allows (decision 56, combat spec).
- The numeric tables live in `data/terrain.yaml`.

## 4. Water (rivers and lakes)
- Rivers and lakes are **impassable for most units** (foot, wheeled, tracked).
- They are crossed by **boats**, **amphibious units** (both have `sail`), **flying units**, or over **bridges** built by engineers.
- There are **no ports or docks**. Units **board or leave a boat when it is next to the shore**. (Decision 86)
- On water, engineers build **bridges only** (normal or reinforced).

## 5. Line of sight and fog of war
- **Mountains and buildings block line of sight.** Vision is computed in 3D, so height matters.
- **Forests conceal** (decision 87): each metre of forest the sight line crosses reduces the observer's effective vision. A flying observer's line crosses less forest, so it sees forest targets more easily than a ground observer.
- **Destroyed objects stop blocking** sight.
- Fog of war is shared per section (see overview). A unit's vision contributes to its own section only; radios relay scouts' information to all sections.
- **A unit fires only at what it sees itself** (decision 59). Shared vision is for awareness, not for aiming.

### Effective vision (decision 59)
Vision is reduced by weather and terrain and extended by height:

`effective vision = vision_range × weather factor × terrain factor + height bonus`

- **Weather factor**: weather is a state of the battle (clear, rain, fog, snow) that **changes randomly, per map**. Each state has a vision factor. **There is no day/night: it is always day.** (Decision 90)
- **Terrain factor**: the terrain where the observer stands (for example a forest lowers it).
- **Height bonus**: an observer standing higher than the target sees farther, up to a cap.
- Then forest concealment applies, and hard blockers (mountains, buildings) still block.
- Values in `data/terrain.yaml` (`vision`, `weather`, `vision_factor` per terrain).

## 6. Terrain types (draft list)
Ground types, trees, roads, towns, rivers, lakes, mountains, floating islands, plus built structures. The exact list and flags (blocks line of sight, gives cover, can be built on) are in `data/terrain.yaml`.

## 7. Floating islands
- Reachable by **flying units**, or via **bridges or ladders built by engineers** from nearby terrain.
- **No height limit for ladders.** Bridges and ladders can be destroyed; ground units can then be **stranded**. (Decision 88)
- Radios are units like any other on an island. **Encampments cannot reach islands.**
- A relic pushed over an island's edge **falls** and lands intact below (decisions 46d, 117).

## 8. Open questions
None open. Performance budgets are technical and out of scope for the spec phase.
