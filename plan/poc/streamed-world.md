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
- **Downloaded models stay out of the build and out of git.** They live in `assets_src/3d_models/` (ignored by git, not listed in `pubspec.yaml`). Only lightened models go to `assets/3d_models/`, which the app bundles whole. `assets/3d_models/SOURCES.md` credits every model there: title, author, source link, licence.
- Licences: CC0 when one exists, else CC-BY with its credit. CC-BY-NC (no commercial use) and models that look taken from another game are for the POC only and never reach `main`.
- Code from `bdero/dashmap` (MIT) may be adapted with credit in the file header. `bdero/dashsurfers` has no licence: its code is read, not copied. Its models are CC0 (Quaternius, Kenney: see its `SOURCES.txt` files) and may be copied with their source noted.

## Starting budgets
Guesses to test, replaced by measured values in step 8.

| Element | Near model | Far model | Textures |
|---|---|---|---|
| Tree | 2,000 triangles, within 100 m of the eye | 12 (cone or crossed quads) | 256² each, cut-out leaves (alpha MASK, never BLEND) |
| Infantry (commander) | 3,000, for the unit in first person and those close to it | 150, no texture | 256² each near, none far |
| Vehicle (tank) | 3,000 | 300, no texture | same |
| Building | 200 per building, batched per chunk | drawn by the ground colour | none |
| Relic, HQ | 6,000 (few of them) | none | 256² each |

A dense forest holds one tree per 10 m cell: about 300 trees within 100 m (600,000 triangles with the near model), and up to 4,096 per chunk with about 30 chunks in range. The far model decides the cost of a forest.

## Models at hand
Downloaded by the owner on 2026-11-13, measured the same day. "Lightened" is what the step 2 pipeline gave; nobody has looked at the results yet.

| File | Content | Source | Lightened | Verdict |
|---|---|---|---|---|
| `tank_tiger_2.glb` (also as `tank_tiger_2/`) | Tiger 2 tank, 460,820 triangles, 92.6 MB, 13 textures | "Tank Tiger 2" by maximus0075550, CC-BY 4.0 | 184,000 with its textures; 16,817 without (1.2 MB) | Too heavy for glTF Transform alone. Blender on the host to reach 3,000, or a low-poly tank instead |
| `soldier.glb` | Soldier, 31,263 triangles, 5.6 MB, 16 parts, 12 textures, a skeleton but no animation | "Soldier" by Vr-cvantorium, CC-BY 4.0 | 3,086 with textures (1.2 MB); 1,536 without (127 KB) | Usable. It stands in its rest pose. Its meshes are named `german_HnG`, so it may come from another game: POC only |
| `low_poly_tree_scene_free.glb` | A scene: 23 trees (bark 276 to 2,775 triangles, leaves 1,530 to 1,824, alpha MASK), 2,665 grass tufts, ground, water; 53.9 MB | "Low Poly Tree Scene Free" by Nicholas-3D, CC-BY 4.0 | not run | Cut two trees out of it. About 1,800 triangles for the smallest |
| `tree_1.glb` | Tree, 19,921 triangles, alpha BLEND, spec-gloss materials | "Realistic Tree" by Daniel, CC-BY 4.0 | 3,981 (the crown loses 98 % of its leaves) | Dropped |
| `futuristic_building.glb` (two copies, textures of two sizes) | One building, 28,048 triangles, 65 parts, 15 materials | "Futuristic Building" by 3DHaupt, **CC-BY-NC 4.0** | 5,622 (1.4 MB) | POC only (no commercial use). One landmark, not a building per cell |
| `futuristic_city.glb` | A whole city in 10 meshes, 229,019 triangles, unlit, one BLEND material | "Futuristic city" by Pasha, CC-BY 4.0 | not run | Not used: the buildings cannot be told apart without cutting it by hand |

The zips hold the same models as `.gltf`; the empty credit files (`town_cedit_2.md`, `tree_credit_2.md`) and the per-model credit files are replaced by `SOURCES.md`.

### Which model each element uses
| Element | Near | Far |
|---|---|---|
| Tree | two trees cut from the tree scene (the smallest, and one mid-sized) | a cone made in code, in the colour of the leaves |
| Commander, and every infantry unit for now | `soldier.glb` with textures (3,086) | `soldier.glb` without textures, reduced to 150 |
| Tank, and every vehicle for now | `tank_tiger_2.glb` without textures (16,817) until Blender or another model gives 3,000 | today's box, until the same |
| HQ | `futuristic_building.glb` lightened (5,622) | none |
| Building (82,000 cells) | boxes made in code, batched per chunk (step 6) | ground colour |
| Relic | today's pillar: no model yet | none |

When downloading more: read the triangle count on the model's page before the licence. Under 5,000 for a vehicle, 3,000 for a character and 2,000 for a tree goes through the pipeline untouched; a model of several hundred thousand does not come down.

## Steps

### 1. Streamed ground and objects: done
`ground_tiles.dart` (pure, tested), `ground_streamer.dart` (GPU). Ground as a quadtree of 64-quad tiles chosen by screen-space error; trees and buildings per 64-cell chunk within 1,500 m; fog recoloured in place.

Run on the web by the owner (2026-11-13): the full `saint_lo` map draws and the result is good. Left open: the map is slow to load (not timed on the web; the map, the move preview and the sight each read it), and no frame rate was measured; both belong to step 8.
Knobs: `GroundSelector.detail`, `GroundStreamer.objectRangeM`, the per-frame build budgets.

### 2. Model pipeline: next
1. **Tidy the downloads.** Move everything the owner downloaded (`assets/3d_models/*` but `SOURCES.md`, and `assets/soldier.glb`) to `assets_src/3d_models/`, add `assets_src/` to `.gitignore`, write `assets/3d_models/SOURCES.md` from the table above, and ask the owner before deleting the zips and the duplicate copies. Today `pubspec.yaml` bundles `assets/3d_models/`, about 250 MB.
2. **`tool/models/`**, a small Node project (`@gltf-transform/core`, `extensions`, `functions`, `cli`, `meshoptimizer`; needs only Node, which the container has):
   - `lighten.mjs <in> <out> --triangles N [--no-textures] [--texture-size 256]`. With textures: `metalrough` (converts spec-gloss materials, which flutter_scene does not read), `weld`, `simplify`, `resize`, `prune`, `dedup`. Without: drop every vertex attribute but the position and every texture, then `flatten`, `join`, `weld`, `simplify`, `normals`, `prune`, `dedup`. The seams of UVs and normals are what stops the simplifier: the tank goes from 460,820 to 184,000 with them and to 16,817 without.
   - `extract.mjs <in> <out> <node name>...` keeps the named nodes of a scene and moves them to the origin, standing on the ground (the trees of the tree scene: find which `Bark` goes with which `Leaves` by position).
   - `inspect.mjs <file>... [--budget tree|infantry|vehicle|hq]` prints triangles, parts, materials, alpha modes, textures and extensions, and fails when over the budget.
3. **`tool/models/blender/`**, scripts the owner runs on the host (`blender -b -P <script> -- <in> <out> ...`), only for what glTF Transform cannot do: bring the tank to 3,000 and 300 triangles (decimate, delete the loose parts smaller than a size), and put the soldier in a standing pose and bake it to a static mesh.
4. **Produce** the models of "Which model each element uses" into `assets/3d_models/`, and list each with its triangle count and size in the step's commit message.

Check: the owner opens each lightened model next to its source in a glTF viewer and says which are acceptable; runs the Blender scripts and reports.

### 3. Trees
- Near model: the two trees of step 2, each two `InstancedMesh` (bark, leaves) per chunk, within 100 m. Which tree a cell gets comes from `treeLook`.
- Far model: a cone made in code, one `InstancedMesh` per chunk, from 100 m to `objectRangeM`. Beyond, the ground colour stands for the forest.
- The level of a chunk follows its distance to the eye; a chunk that straddles 100 m draws near (chunks are 640 m wide, so try 16-cell chunks for trees if the switch shows or costs too much).
- To verify first: that flutter_scene draws glTF alpha MASK as a cut-out without a custom material (dashsurfers uses its own `.fmat` for foliage).

Check: a forest in first person and from above, the switch between the two levels, the frame rate inside the densest forest of `saint_lo`.

### 4. Units: commander and tank
- One `InstancedMesh` per unit type, per level and per part of its model, one instance per unit, moved with `setInstanceTransform`. About 1,000 units then cost a few draws per unit type. Static models only: a skinned model cannot be instanced (stack decision 4), so animation is out of this POC.
- The soldier has 16 parts and 12 textures, so 16 draws: acceptable near, and the reason its far model has no texture and one part.
- The unit under first-person control and the units within 100 m use the near model; the others the far model.
- A debug switch spawns 1,000 units around the camera.

Check: 1,000 units on screen, top-down and first person; the soldier's pose and size next to a tree and a tank.

### 5. Team colours
Each team has one colour, which tints its units, HQ and relics. Five teams (MAP-04).

Proposed palette (Okabe–Ito), in team order:

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
- Today's red: 1.9 from the forest ground for a protanope, 5.2 from grass for a deuteranope. The red team disappears on the ground.
- Weak points left: vermillion is 5.3 from grass (deuteranope), yellow 5.8 from sand (tritanope), blue 0.4 from a lake. No colour is safe against every ground, so a unit also needs a cue that is not a hue.

To test:
- **Where the tint goes.** `InstancedMesh.addInstance(color:)` multiplies the colour of a whole part. Far models have no texture, so they take the team colour whole: from above a unit is a figure in its team's colour. Near models keep their textures; try the tint on chosen parts only (the soldier's helmet and jacket parts, the tank's hull), mixed with white so the texture still shows. A model tinted whole in black loses its shape.
- **The second cue.** A light or dark rim around the team-coloured disc under each unit, so a unit stands out by lightness on any ground.
- The palette on a device, on grass, forest, sand, road and fogged ground.

Check: the owner, and if possible a colour-blind player, tell five teams apart top-down at the usual zoom.

### 6. Buildings batched per chunk
One mesh per chunk built in code from the buildings' cells (walls and a roof per cell, neighbours merged; dashmap batches 24,000 vertices per mesh), instead of an instanced box per cell. The HQ takes the lightened landmark building.

### 7. Ground colour and fog in a material
A `.fmat` material that reads the terrain and the fog from textures, so a coarse tile keeps its roads and a fog change costs one texture upload instead of recolouring tiles.

### 8. Measure and decide
Profile mode on the Pixel 6 and on the web (dashmap's `tool/profile.dart` reads UI and raster times through the VM service), and the time to load `saint_lo`. Fill the budget table with measured values, answer the four questions, and write the stack record proposal.
