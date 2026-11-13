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
- Models are **CC0** when one exists. A CC-BY model needs its credit in `assets/3d_models/SOURCES.md` and in the battle's credits. A model without a licence is not used.
- Code from `bdero/dashmap` (MIT) may be adapted with credit in the file header. `bdero/dashsurfers` has no licence: its code is read, not copied. Its models are CC0 (Quaternius, Kenney: see its `SOURCES.txt` files) and may be copied with their source noted.
- One commit per step on this branch, when the step's check passed. The branch is never merged.
- The GPU code cannot run in the agent's container. Every step ends with the owner running it on a device; the step's "Check" says what to look at.

## Starting budgets
Guesses to test, replaced by measured values in step 8.

| Element | Near model | Far model | Textures |
|---|---|---|---|
| Tree | 300 triangles | 12 triangles (cone or crossed quads) | one shared 256² atlas, cut-out leaves (alpha MASK, never BLEND) |
| Infantry (commander) | 1,500 | 150 | one shared 256² palette, or material colours only |
| Vehicle (tank) | 3,000 | 300 | same |
| Building | 200 per building, batched per chunk | drawn by the ground colour | same |
| Relic, HQ | 2,000 | none (few of them) | same |

A dense forest chunk holds up to 4,096 trees and about 30 chunks are in range, so the far model decides the cost of a forest, not the near one.

## Steps

### 1. Streamed ground and objects: done
`ground_tiles.dart` (pure, tested), `ground_streamer.dart` (GPU). Ground as a quadtree of 64-quad tiles chosen by screen-space error; trees and buildings per 64-cell chunk within 1,500 m; fog recoloured in place.

Run on the web by the owner (2026-11-13): the full `saint_lo` map draws and the result is good. Left open: the map is slow to load (not timed on the web; the map, the move preview and the sight each read it), and no frame rate was measured; both belong to step 8.
Knobs: `GroundSelector.detail`, `GroundStreamer.objectRangeM`, the per-frame build budgets.

### 2. Model pipeline
A script `tool/lighten_model.sh <in> <out> <ratio>` around glTF Transform (`npx @gltf-transform/cli`, Node only, no Blender):
`metalrough` (converts spec-gloss materials, which flutter_scene does not read) → `weld` → `simplify --ratio R --error E` → `resize --width 256 --height 256` → `prune` → `dedup`.
Models are downloaded as glTF 2.0, as one binary `.glb` when offered (`.gltf` with its `.bin` and textures also loads), static rather than rigged. FBX, OBJ, USDZ and `.blend` are not read by flutter_scene and would need Blender to convert.
A second script prints a model's triangles, textures, alpha modes and extensions and fails when it is over the budget of its kind.

Measured on 2026-11-13 (numbers only: nobody has looked at the results yet):

| Model | Before | After `simplify` | Note |
|---|---|---|---|
| `tree_1.glb` crown | 11,865 triangles | 237 | 2 % of the leaves left: to be looked at |
| `tree_1.glb` trunk and branches | 8,056 | 3,744 | stops there whatever the settings |
| `tree_1.glb` file | 6.8 MB | 0.9 MB | after `resize` to 256² |
| Quaternius `Pine_5` | 1,646 | 1,218 | stops there |
| Quaternius `CommonTree_5` | 3,182 | 1,762 | stops there |

The simplifier works on closed, connected surfaces (a hull, a body, a trunk). A mesh made of many small separate pieces (leaf cards, twigs) either resists or loses pieces. So: vehicles, characters, buildings and rocks go through the script; a tree is chosen low-poly from the start, or its far model is made in code.

Check: the owner opens a lightened model next to its source (any glTF viewer) and says whether it is acceptable.

### 3. Trees
- Near model, candidates to compare on a device: Quaternius `Pine_5` and `CommonTree_5` from dashsurfers (CC0) after step 2; a tree of the same look built in code at about 300 triangles; the owner's `tree_1.glb` after step 2 (CC-BY "Realistic Tree" by Daniel, its credit is missing).
- Far model: a cone or two crossed quads, in the leaf colour. One `InstancedMesh` per chunk and per level; the level of a chunk follows its distance to the eye. Beyond `objectRangeM` the ground colour stands for the forest.
- To verify first: that flutter_scene draws glTF alpha MASK as a cut-out without a custom material (dashsurfers uses its own `.fmat` for foliage).

Check: a forest in first person and from above, the switch between the two levels, the frame rate inside the densest forest of `saint_lo`.

### 4. Units: commander and tank
Neither example app has a soldier or a tank. dashsurfers has the Kenney race cars (1,430 triangles, materials only, no texture), good to prove the vehicle path before a tank is chosen, and the Flutter mascot (4 MB, skinned), not for this game.
- Tank candidates: the owner's "Tank Tiger 2" (CC-BY, credited in `tank_credit_1.md`, the file is not in the repository) through step 2; a CC0 low-poly tank (OpenGameArt "Low poly tank assets" to check).
- Commander candidates: Kenney "Blocky Characters" (CC0, glTF), Sketchfab "RTS Mercenaries 2" (CC0), to check; the licence is read on each download page.
- Drawing: one `InstancedMesh` per unit type and per part of its model, one instance per unit, moved with `setInstanceTransform`. About 1,000 units then cost a few draws per unit type. Static models only: a skinned model cannot be instanced (stack decision 4), so animation is out of this POC.
- The unit under first-person control keeps the near model; the others switch to the far model with distance.

Check: 1,000 units on screen (a debug switch that spawns them), top-down and first person.

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
- **Where the tint goes.** `InstancedMesh.addInstance(color:)` multiplies the colour of a whole part. Convention to try: the parts of a model whose material is named `team` take the team colour, the others keep their own (the Kenney car already has such a material, `red`). A model tinted whole turns black for team 5 and loses its shape.
- **The second cue.** A light or dark rim around the team-coloured disc under each unit, so a unit stands out by lightness on any ground.
- The palette on a device, on grass, forest, sand, road and fogged ground.

Check: the owner, and if possible a colour-blind player, tell five teams apart top-down at the usual zoom.

### 6. Buildings batched per chunk
One mesh per chunk built from the buildings' cells (dashmap batches 24,000 vertices per mesh), instead of an instanced box per cell. The Kenney city buildings of dashsurfers (about 1,200 triangles, one colour-map texture) are candidates for a near model in towns.

### 7. Ground colour and fog in a material
A `.fmat` material that reads the terrain and the fog from textures, so a coarse tile keeps its roads and a fog change costs one texture upload instead of recolouring tiles.

### 8. Measure and decide
Profile mode on the Pixel 6 and on the web (dashmap's `tool/profile.dart` reads UI and raster times through the VM service). Fill the budget table with measured values, answer the four questions, and write the stack record proposal.
