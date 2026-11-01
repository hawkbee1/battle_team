# Stack decision 5: map format and authoring

Status: **proposed** (milestone M2, Issue 5). Rules: MAP-04 (up to 10 × 50 km), MAP-05 (one loader on server and client), MAP-06, MAP-08, MAP-09, MAP-11 to MAP-19 (movement classes and terrain), MAP-22 to MAP-25 (water, islands), MAP-36 to MAP-38 (floating islands); the navigation model of M3 Issue 2; Q-MAP-09 (world-change budget). The flutter_scene facts come from `04-client-and-rendering.md`.

## What the rules require
- Heights, terrain types (grass, forest, town, water, mountain…), floating islands, and objects (trees, buildings, walls, roads, bridges, ladders). All numbers come from `plan/data/*.yaml`.
- One loader, used by the server and the client (MAP-05).
- The navigation model of M3 is built from the map (M3 Issue 2): a grid of cells with a ground height and a terrain type.
- Changes during a battle: constructions, destroyed objects, craters (MAP-06, MAP-09).

## Options
1. **Vector map** (polygons for areas, lines for roads, points for objects). Good for towns, poor for 50 km of varied height, and the navigation grid must be rebuilt from it.
2. **Raster heightmap plus layers, with an object list.** Heights in a 16-bit image, terrain types in an indexed image, objects in a text file per tile. Matches the navigation grid directly. Real elevation data can be imported.
3. **Option 2 cut into fixed tiles**, each with its heights, terrain and objects. Lets the client load only the tiles near the camera, and lets a world change touch one tile.

## Choice
**Option 3.** Cell size **10 m** (a proposal: it gives 5 million cells on a 10 × 50 km map). Tiles of **256 × 256 cells** (2.56 km square). Per tile:
- `heights`: 16-bit image, one value per cell, in metres above a fixed base;
- `terrain`: indexed image, one terrain type per cell, from `data/terrain.yaml`;
- `objects.yaml`: trees, buildings, walls, roads, bridges, ladders, floating islands, each with its armour type from `data/combat.yaml`.

**How it reaches the screen (flutter_scene):**
- **Terrain** has no component in flutter_scene. Each tile becomes one terrain mesh, built in code from its heightmap (the `MeshGeometry` pattern of the procedural skill). A tile of 256 × 256 cells has 257 × 257 vertices, more than the 65,535 a `Uint16` index can address, so the tile uses `Uint32List` indices.
- **Terrain LOD**: each tile gets two or three geometric levels (`LodComponent`), so distant tiles cost less.
- **Objects** (trees, buildings, walls): prefabs built from glTF at build time (`.glb` through the build hook, loaded as `.fsceneb`). Repeated objects such as trees are `InstancedMesh`es, one per object type per tile.
- **Textures**: KTX2 (ETC1S) for terrain and object textures, to fit the memory budget on phones.

A **map builder** command (a Dart package in the repository) validates a map and writes the tiles. It checks what can be checked statically: terrain types and armour types exist, bridges and ladders connect land to land, islands are linked to the ground only by bridges or ladders (MAP-36), no object sits on a cell it cannot occupy. The map builder does not ship with the client. The same tile data is read by the server (for the rules) and the client (for display), through the one loader of MAP-05.

## Sizes and budgets
- A 10 × 50 km map: 1,000 × 5,000 cells. Heights 2 bytes per cell (10 MB raw), terrain 1 byte per cell (5 MB raw). Compressed PNG is much smaller. The client downloads the tiles near the camera.
- Vertices: each cell has a vertex, so 5 million vertices in total across all tiles. Only the tiles near the camera are drawn at full detail.
- In memory on the host: about 20 MB for one map copy, shared by all its battles (decision 1).
- **World-change budget** (answers Q-MAP-09 at the level of the stack): a change is applied on the host in under 10 ms, and reaches the clients in under 1 second. The path update budget is M3 Issue 5's: only the cells touched by the change are re-computed. Both are tests in `performance-tests.md`.

## Consequences
- The map files are data, not code: they are versioned like `plan/data`, and the builder checks them in tests.
- Floating islands are separate surfaces, linked only by bridges and ladders. The navigation model keeps them as separate regions (M3 Issue 2).
- The cell size is the main lever of pathfinding cost. Changing it later means rebuilding every map, so it is chosen here and checked with the first benchmark (M3 Issue 6).
- Terrain tile meshes are rebuilt when a crater or a construction changes a tile; the cost of that rebuild is a benchmark in `performance-tests.md`.
