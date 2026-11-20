# POC: streamed world and light assets

Branch `poc/streamed-world`, started 2026-11-13. A throwaway experiment: nothing here is a rule or a stack decision.

## Goal
Find out whether Battle Team can draw the full `saint_lo` map (1000 × 5000 cells, about 200,000 trees, 82,000 buildings) with a 3D model for every element of the game, inside the frame budget of stack decision 4, on the Pixel 6 and on the web.

The POC ends with answers to these questions:
1. Does a ground made of streamed tiles hold the frame budget on the full map?
2. Which triangle and texture budget per kind of model keeps a battle light?
3. Is there a repeatable way to turn a downloaded model into one that fits the budget?
4. How does a unit show its team, for five teams, without relying on a colour a colour-blind player confuses?

## Working rules of the POC
- No coverage gate and no plan rules on this branch. Pure logic still gets tests, because it is cheap and it is what would move to `main`.
- Nothing goes to `main` from here. What works becomes a stack record proposal (asset budget and pipeline, streamed ground) that the designer confirms; the code is then rewritten to the usual standard.
- One commit per step on this branch, when the step is written and its tests pass. No push unless the owner asks. The branch is never merged.
- The GPU code cannot run in the agent's container, and the agent cannot look at a model. Every step ends with a "Check" the owner does on a device or in a glTF viewer; the agent stops there and says what to look at.
- **Downloaded models stay out of the build.** Each lives unpacked in `assets_src/3d_models/<name>/` with the `license.txt` it came with (in git, not listed in `pubspec.yaml`). Only lightened models go to `assets/3d_models/`, which the app bundles whole, and `assets/3d_models/SOURCES.md` credits them. A source over 10 MB is not kept: it does not come down to a budget.
- Licences: CC0 when one exists, else CC-BY with its credit. No CC-BY-NC (no commercial use).
- Code from `bdero/dashmap` (MIT) may be adapted with credit in the file header. `bdero/dashsurfers` has no licence: its code is read, not copied. Its models are CC0 (Quaternius, Kenney: see its `SOURCES.txt` files) and may be copied with their source noted.

## Starting budgets
Guesses to test, replaced by measured values in step 8.

| Element | Near model | Far model | Textures |
|---|---|---|---|
| Tree | 1,200 triangles, within 100 m of the eye | 12 (cone or crossed quads) | 256² each, cut-out leaves (alpha MASK, never BLEND) |
| Infantry (commander) | 3,000, for the unit in first person and those close to it | 150, no texture | 256² each near, none far |
| Vehicle (tank) | 3,000 | 300, no texture | same |
| Building | 200 per building, batched per chunk | drawn by the ground colour | none |
| Relic, HQ | 6,000 (few of them) | none | 256² each |

A dense forest holds one tree per 10 m cell: about 300 trees within 100 m (300,000 triangles with the near model), and up to 4,096 per chunk with about 30 chunks in range. The far model decides the cost of a forest.

## Models at hand
Downloaded by the owner on 2026-11-13 from Sketchfab, all CC-BY 4.0, measured the same day. "Lightened" is what `tool/models/build.sh` writes to `assets/3d_models/` (step 2); nobody has looked at the results in a viewer yet.

| Source (`assets_src/3d_models/`) | Content | Lightened |
|---|---|---|
| `stylized_pine_tree` | Pine, 939 triangles, one part, three 2048² textures, opaque | `tree_pine_near`: 939, 256² textures (175 KB) |
| `flow_tree` | Leafy tree, 1,113 triangles, one part, vertex colours, no texture, opaque | `tree_flow_near`: 1,113, as is (58 KB) |
| `soldier` | German soldier, 31,263 triangles, 16 parts, 12 textures, a skeleton but no animation | `infantry_near`: 2,998, 12 textures of 256² at most (1.1 MB); `infantry_far`: 147, one part (12 KB) |
| `concept_tank` | Tank, 5,454 triangles, 10 parts, one material, one 4096² texture, a skeleton and one animation | `vehicle_near`: 2,991, one 256² texture (166 KB); `vehicle_far`: 299, one part (23 KB) |
| `hcr2_tank` | Cartoon tank, 70,714 triangles (62,784 in its 12 wheels), parts named chassis, tower, gun, wheels; two materials, 4096² textures | `vehicle_hcr2_near`: 2,996, no textures, the tower and the gun parts of their own (218 KB); with textures it stops at 10,514 |
| `low_poly_building` | Building, 4,353 triangles, 7 parts, 6 material colours, no texture | `hq_near`: 3,535 (204 KB) |

`hcr2_tank` is the tank of the game Hill Climb Racing 2 redrawn by a fan: the owner confirms it may be used before it reaches `main`.

### Which model each element uses
| Element | Near | Far |
|---|---|---|
| Tree | `tree_pine_near` and `tree_flow_near`, as they are | a cone made in code, in the colour of the leaves |
| Commander, and every infantry unit for now | `infantry_near` | `infantry_far` |
| Tank, and every vehicle for now | `vehicle_near`; `vehicle_hcr2_near` as the second candidate, for its separate tower and gun | `vehicle_far` |
| HQ | `hq_near` | none |
| Building (82,000 cells) | boxes made in code, batched per chunk (step 6) | ground colour |
| Relic | today's pillar: no model yet | none |

When downloading more: read the triangle count on the model's page first. Under 5,000 for a vehicle, 3,000 for a character and 1,200 for a tree goes through untouched. A model of several hundred thousand triangles does not come down (a 460,820-triangle tank stopped at 184,000 with its textures and 16,817 without), and a tree made of leaf cards and twigs stops near half.

## Steps

### 1. Streamed ground and objects: done
`ground_tiles.dart` (pure, tested), `ground_streamer.dart` (GPU). Ground as a quadtree of 64-quad tiles chosen by screen-space error; trees and buildings per 64-cell chunk within 1,500 m.

Run on the web by the owner (2026-11-13): the full `saint_lo` map draws and the result is good. Left open: the map is slow to load (not timed on the web; the map, the move preview and the sight each read it), and no frame rate was measured; both belong to step 8.
Knobs: `GroundSelector.detail`, `GroundStreamer.objectRangeM`, the per-frame build budgets.

### 2. Model pipeline: written, waiting for the Check
Sources are in `assets_src/3d_models/`, credits in `assets/3d_models/SOURCES.md`.

1. **`tool/models/`**, a small Node project (`@gltf-transform/core`, `extensions`, `functions`, `cli`, `meshoptimizer`; needs only Node, which the container has):
   - `lighten.mjs <in> <out> --triangles N [--no-textures] [--texture-size 256] [--error 1] [--keep-parts name,name]`. Both recipes first bake a skinned source in the pose of the file (the game draws models as instances, which a skeleton forbids) and drop its animations. With textures: `metalrough` (converts spec-gloss materials, which flutter_scene does not read), `weld`, `simplify`, a textured BLEND material turned into MASK (the soldier's helmet net), `resize`, `prune`, `dedup`. Without: drop every vertex attribute but the position and every texture, one neutral material for all, then `flatten`, `join`, `weld`, `simplify`, `normals`, `prune`, `dedup`; the result is one part (but the `--keep-parts` ones), flat-shaded. The seams of UVs and normals are what stops the simplifier: `hcr2_tank` stops at 10,514 with them and reaches 294 without.
   - `inspect.mjs <file>... [--budget tree|infantry|vehicle|hq]` prints triangles, parts, materials, alpha modes, textures and extensions, and fails when over the budget (a file named `*_far.glb` is held to the far budget).
   - `build.sh` runs `lighten.mjs` for every row of "Which model each element uses" and writes `assets/3d_models/<element>_<near|far>.glb`, so the folder is rebuilt from the sources by one command, and checks each file against its budget. `npm test` in `tool/models/` runs the tests.
2. **Produced**: the models of the table above. The models keep the scale of their download (soldier 194 units tall, tank 2.9 long, pine 463, flow tree 5): steps 3 and 4 scale them in code.
3. The soldier keeps the pose of its download (arms slightly down and out): the owner does not change it for now.

Check: the owner opens each lightened model next to its source in a glTF viewer and says which are acceptable. To look at: that `concept_tank`, whose parts hung on a skeleton, is assembled; the far models from a distance (the far tank has lost its antenna and its wheels are spikes); the soldier's helmet net, now a cut-out.

### 3. Trees: written, waiting for the Check
`tree_model.dart` loads the two trees of step 2 (`treeKinds`: asset, height in metres, leaf colour); `ground_tiles.dart` holds the logic (tested); `ground_streamer.dart` draws.

- Near model: one `InstancedMesh` per tree model and per chunk, within `treeNearM` (100 m). Which tree a cell gets comes from `treeLook`: half pines, half flow trees, mixed cell by cell. The pine is drawn 13 m tall and the flow tree 9 m, before the 0.8 to 1.25 of `treeLook`.
- Far model: a cone of 6 triangles made in code, as tall and as wide as its tree, in the colour of its leaves; one `InstancedMesh` per chunk, from 100 m to `objectRangeM`. Beyond, the ground colour stands for the forest.
- The level of a chunk follows the distance from the eye to its nearest ground, and a chunk keeps its level until 25 % past the limit. Its cones stay on the GPU while it is near, so only the models are made and dropped at the switch.
- Trees have chunks of their own, of `treeChunkCells` cells: **16, not 64**. Counted on `saint_lo`: in its densest forest (around cell 24, 3368) 64-cell chunks draw 8,824 models at once (about 9 million triangles), 32-cell ones 4,041 and 16-cell ones 2,304, which is still eight times the 300 of "Starting budgets". The price is draws: up to about 280 chunks of cones within 1,500 m instead of 30.
- flutter_scene's standard material multiplies the vertex colours (glTF `COLOR_0`) into the base colour, and its importer reads them: read in its code, not seen on a screen. The flow tree's material is grey (0.5) and half metallic: the loader sets the metal to 0, the grey stays.

Knobs: `GroundStreamer.treeNearM`, `treeChunkCells`, `treeBuildsPerFrame`; `treeKinds`. `GroundStreamer.counts` gives the trees drawn as models and as cones.

Check: a forest in first person and from above; that the flow tree shows its colours (green leaves, brown trunk) and is not too dark; the sizes of the two trees next to a unit; the switch between the two levels, in shape and in colour (the cones' colour is the mean green of each model); the frame rate inside the densest forest of `saint_lo` (cell 24, 3368), with `treeChunkCells` at 16 and at 32.

### 4. Units: commander and tank: done but one check
`unit_model.dart` loads the models of step 2 (`infantryKind`, `vehicleKind`: assets, size in metres, which way the front is); `unit_levels.dart` holds the logic (tested); `unit_instances.dart` draws; `scene_battle_world.dart` moves the units.

- One `InstancedMesh` per unit model, per level and per part of the model, one instance per unit, moved with `setInstanceTransform` only when the unit moved. All units then cost 30 draws at most: 16 for the near soldier, 10 for the near tank (its 10 parts share one material: joining them is a job for `lighten.mjs`), 1 each for the two far models and 2 for the discs (disc and rim, step 5). Static models only: a skinned model cannot be instanced (stack decision 4), so animation is out of this POC.
- Every infantry unit is the soldier and every vehicle the tank, drawn whole: its tower does not turn.
- A unit within `nearM` (100 m) of the eye uses the near model, the others the far model; it keeps its level until 25 % past the limit. The unit under first-person control is not drawn at all, as before: the eye is inside it.
- **Units are drawn at their real size**, no longer three times bigger: the soldier 1.8 m tall, the tank 5.85 m long. From above a unit shows by its disc (3 m in radius, in its team's colour: step 5).
- A unit faces where it last moved. `frontYaw` of each kind turns its model's front onto the way it walks (set by the owner on a screen).
- The selected unit and the target have a ring around their disc (yellow, white) instead of a highlight of the model.
- The debug switch is the last button of the toolbar (the group icon): 1,000 units in a square of 32 by 32, 8 m apart, around the middle of the screen, four soldiers for one tank, of the five teams in turn. Each walks a circle of 3 m, so every instance moves every frame. They are only drawn: no label, no tap. The switch logs the counts (`SceneBattleWorld.unitCounts`).

Knobs: `UnitInstances.nearM`; `sizeM` and `frontYaw` of `infantryKind` and `vehicleKind`; `SceneBattleWorld.crowdCount`; spacing, circle and speed in `crowdAt`.

Checked by the owner (2026-11-13): 1,000 walking units draw, top-down and in first person; they walk forwards; both levels stand on the ground and the switch at 100 m looks good; from above a unit shows as its disc and a white figure, partly hidden by the ground on a steep slope, which is accepted.

Check left: the soldier's size and pose next to a tree and a tank, in first person.

### 5. Team colours: written, waiting for the Check
Each team has one colour, which tints its units, HQ and relics. Five teams (MAP-04). `team_colours.dart` holds the logic (tested); `unit_instances.dart` and `scene_battle_world.dart` draw. A team's place is the number its id ends with (`team-3` is the third, as the backend names them); an id with no place gets a grey.

Palette (Okabe–Ito), in team order:

| Team | Colour | sRGB |
|---|---|---|
| 1 | blue | `#0072B2` |
| 2 | yellow | `#F0E442` |
| 3 | vermillion | `#D55E00` |
| 4 | sky blue | `#56B4E9` |
| 5 | black | `#111111` |
| unowned relic | white | `#FFFFFF` |

A battle of two teams is then blue against yellow. Measured with a simulation of protanopia, deuteranopia and tritanopia (distance in OKLab × 100; under 10 is hard to tell apart):
- The five colours: the closest pair is at 18.9 in the worst case. With purple instead of sky blue it falls to 9.6 (blue and purple for a protanope).
- The red the game had before: 1.9 from the forest ground for a protanope, 5.2 from grass for a deuteranope. The red team disappeared on the ground.
- Weak points left: vermillion is 5.3 from grass (deuteranope), yellow 5.8 from sand (tritanope), blue 0.4 from a lake. No colour is safe against every ground, so a unit also has a cue that is not a hue.

A unit shows its team three ways:
- **Its model.** A far model has no texture and takes the colour whole. A near model multiplies its textures by the colour mixed with white (`nearTintMix`, 0.75 of the way from white to the colour, so the texture shows and a black team keeps its shape), on chosen parts only: the soldier's tunic, trousers and helmet (parts 0, 1 and 3 of `infantry_near`, picked from their textures, not seen on the model), the whole tank (one material).
- **Its disc**, in the colour.
- **A rim** around the disc (its outer fifth, 0.6 m), white or black, whichever contrasts more with the colour: white for the blue and the black team, black for the others and for the white relic. A lightness cue that does not depend on a hue. Disc and rim are one instanced mesh of two parts.

HQs and relics take the same colours through `teamColor` (flag, ring, pillar); neither has a rim. They are now made again when their team changes: a relic kept the colour of its first owner.

Colours reach the materials as linear RGB (`srgbToLinear`); what the scene's lighting and tone mapping make of them is for the Check. The debug crowd shows the five teams in turn, soldiers and tanks of each, no unit next to one of its own team (`crowdUnitAt`).

Knobs: `teamPalette`, `nearTintMix`, `tintParts` of `infantryKind`, `_rimShare` of `UnitInstances`.

Check: the owner, and if possible a colour-blind player, switch the crowd on and tell the five teams apart top-down at the usual zoom, on grass, forest, sand, road and fogged ground; say whether the rim helps. In first person and close to a unit: that the tint of the soldier's tunic, trousers and helmet shows through the textures, is neither too dark nor washed out, and that the black team is still a soldier (and which parts of the soldier should take the colour); the tank tinted whole. An HQ and a relic in each colour, a relic changing colour when it is captured, and an unowned relic white.

### 6. Buildings batched per chunk: written, waiting for the Check
`building_mesh.dart` holds the logic (tested); `ground_streamer.dart` draws the buildings; `unit_model.dart` loads the HQ's model and `scene_battle_world.dart` draws it.

- The buildings of a 64-cell chunk are meshes made in code, 24,000 vertices each at most (as dashmap batches), instead of an instanced box per cell: one draw for most chunks, three for a chunk full of buildings.
- A building cell is a block that fills its cell (10 m, where the box was 8 m), under the flat roof of its building (`buildingTops`): one roof for all the cells of a building, above the highest ground under them, 5 to 8 m for a house of one or two cells, 8, 11 or 14 m for a bigger one, and one of six looks (slate or tiled roof, stone, render, concrete or brick walls), picked from its first cell. A wall stands on each side where what is next door, in this chunk or the next, is lower: none between cells of one building or of two of the same height, the step from the higher roof down to the lower one between two buildings, the whole wall where none stands.
- An outer wall goes half a metre under the lowest ground along its side. A block costs 2 to 10 triangles, against 12 for the box.
- Roofs and walls take their colours from the vertices (`buildingLooks`), under one material. It is double-sided: the triangles are wound counter-clockwise seen from outside (tested), but which side flutter_scene culls was not seen on a screen.
- Buildings are not shaded by the fog, as before.
- The HQ is `hq_near` drawn 12 m tall in the model's own colours, at the centre of the ring and next to the flag, which still show its team. Five nodes of 6 parts at most: no instancing.

Knobs: `sinkM` and `maxVertices` of `buildingArrays`; `buildingHeightM`, `buildingLooks`; `hqKind.heightM`. The crowd switch also logs the buildings drawn: triangles, meshes and chunks (`SceneBattleWorld.buildingCounts`).

Check: a town from above and in first person: that walls and roofs are lit from outside (no black or missing face), that the two colours show, that no gap shows under a wall on a slope, and whether terraces of roofs look right on a hillside; the seam between two chunks inside a town (no wall, no gap); the size of a block next to a unit and a tree; the counts logged over the densest town. The HQ: its size next to a unit and inside its ring, that it stands on the ground and that its colours are not too dark.

### 7. Ground colour and fog in a material: written, waiting for the Check
`assets/materials/ground.fmat` is the material; `ground_pages.dart` holds the logic (tested); `ground_material.dart` makes the textures and the materials; `ground_tiles.dart` and `ground_streamer.dart` draw with them.

- A **page** is the cells of one root tile of the quadtree: 1,024 cells a side, so `saint_lo` has five, of 1,000 × 1,025 texels (the last row is the next page's first, as for tiles). A page has a terrain texture, a fog texture and its own instance of the material; every tile under the root draws with it. One texture for the whole map would be 5,000 texels long, past the 4,096 a phone or a browser takes for sure, and a fog change would upload all of it.
- A tile's vertices hold a place in the textures of their page and the grey of their slope, no longer a terrain colour or a fog. The material is unlit and computes per pixel what was computed per vertex: terrain × slope, faded to `FogShade.tint` by what the fog lets the cell keep. So a coarse tile shows every cell it spans: its roads, its rivers and the fog's edge.
- The terrain texture is made once, with a mip chain (`TextureContent.data`: the colours are linear and are averaged as they are), sampled trilinear and anisotropic.
- The fog texture holds, in red, what each cell keeps of its colour: 255 in sight, 140 seen once, 46 never seen. It is sampled linear, without mips. When the fog changes, the pages where a cell changed upload theirs again, `fogUploadsPerFrame` (1) a frame, the nearest first; no tile is touched. An upload is the whole page, 4 MB on `saint_lo`: flutter_scene's `Texture2D` only makes RGBA textures, and one byte in four is used.
- On the GPU for `saint_lo`: 27 MB of terrain with its mips, and up to 20 MB of fog.
- `hook/build.dart` compiles the material (flutter_scene's `buildMaterials`) into `flutter_scene_generated/`, which is in `pubspec.yaml` and in git only by its `.gitignore` files. The models stay `.glb` files read at run time. `BattlePage` makes the pages after the models (`loadGroundMaterials`).
- Compiled in the container for Linux (the same GLES and Vulkan shaders as Android's) by `flutter test`, which runs the hook. Not compiled for the web, and not drawn. That the first row of a texture is its north is taken from how flutter_scene draws a glTF texture (rows as they come, coordinates not flipped), not seen on a screen.

Knobs: `GroundStreamer.fogUploadsPerFrame`; `terrainMipmaps` of `loadGroundMaterials`; `FogShade`; `terrainColors`.

Check: near the eye the ground is as before (colours, slopes, the three levels of fog), with north and south the right way round inside a page (a road under a unit, the fog around it). From above: a far tile keeps its roads and rivers, and nothing changes colour when a tile changes level; far roads do not shimmer when the camera moves (with `terrainMipmaps` off to compare). Where two pages meet (every 10,240 m to the south): no line in the colours or in the fog. The fog follows a moving unit without a hitch, also when its sight crosses two pages. The time the map takes to load, against step 6.

### The owner's look at the maps (2026-11-20): written, waiting for the Check
The owner saw four flaws: towns as grey zones, rivers and roads the units ignore, and the map ending in the void.

- **Towns.** OpenStreetMap puts buildings on only about 15 % of a town's residential land (the map held all 8.5 km² of them); the rest was `town_street`, drawn grey. On the owner's word, battle_map's import builds towns up (`blocks` in the import file): every free town street cell becomes a building, grouped with the buildings already there in blocks of 4 × 4 cells at most. `saint_lo` was re-imported from its downloads of 2026-11-05: 270,434 building cells in 50,205 objects (were 81,741 in 46,519); trees of woods no longer stand on roads (5,722 were). Every relic and HQ is still reached on foot from the north HQ. Units now cross a town by its roads. Q-MAP-29 holds the hit points of a block.
- **Rivers and roads.** The host already sends units round a river by a bridge and along roads where they cost less; the client drew them gliding straight from where they were to where they went, and drew no bridge. A moving unit now glides along the path the move preview plans (`UnitRoutes`, `Glide`): the host's search on the same map, a guess for the drawing since the host sends no path (decision 236). Straight past 2 km, where a search could take a frame. Bridges are drawn as decks (`bridgeDecks`, a metre above the highest ground around), and units stand on them. Roads are asphalt grey (were beige).
- **Edge and sky.** Cliffs close the map on its four sides (`edgeCliffArrays`), as the owner asked: a wall climbs 150 m from the ground at the edge, dark rock at its foot, lighter rock, earth at the top, facing into the map; high ground runs 3 km out from its top, so the map lies in a valley. The sky is flutter_scene's gradient sky in the colours of the weather (`weatherLooks`: clear with a sun; rain, fog and snow overcast), and the far ground fades into a haze of the horizon's colour, from 1,500 m (where trees and buildings stop) to 20 km in clear weather and 1.5 km in fog. The ground's material does the haze itself (`haze_*` in `ground.fmat`): flutter_scene's fog skips unlit materials.

Knobs: `UnitRoutes.maxSearchM`; `bridgeDeckRiseM`, `bridgeSlabM`, `bridgeLook`; `riseM`, `lipM`, `rimM` and the four colours of `edgeCliffArrays`; `weatherLooks`, `WeatherLook.hazeStartM`; `terrainColors`.

Check: Saint-Lô from above and in first person: blocks between the streets, their heights and looks, no gap or missing face; a unit sent across the Vire takes a bridge and walks on its deck, and one sent along a road follows it; the 1 km map's two bridges; the cliffs from above and in first person at an edge of the map; the sky and the haze in each weather (the host starts a battle in the first of its settings' `weather.states` and does not change it yet: put rain, fog or snow first), and whether the haze hides too much or too little; that team colours still show on the new asphalt grey; the time `saint_lo` takes to load, against step 7.

### 8. Measure and decide
Profile mode on the Pixel 6 and on the web (dashmap's `tool/profile.dart` reads UI and raster times through the VM service), and the time to load `saint_lo`. Fill the budget table with measured values, answer the four questions, and write the stack record proposal.
