# Milestone 3: pathfinding

Goal: a headless module that finds the cheapest path in AP for every movement class and profile, and for pushed relics and the moving HQ, on the battle map. It returns each path as the samples the rules core takes as input: `(terrain type, signed slope in degrees, length in m)` (M4 Issue 4). **No rendering, no network.** Stack from M2 (`stack/01-simulation-host.md`, `stack/05-map-format.md`): Dart, in the package `battle_pathfinding` (its own repository, hawkbee `packages/battle_pathfinding`, stack decision 7), with the 10 m cell grid of the map format.

Each issue below is ready to be created as a GitHub issue in the milestone "M3 – Pathfinding". Labels: `pathfinding` plus the one listed.

## Why before the rules core, and what it does not depend on
- M4 computes the AP cost of a path, but nothing produces paths, and maps are up to 10 × 50 km (MAP-04).
- The map format is chosen with the technical stack (M2, Issue 5). This milestone works on a **navigation model** built from it, plus a small fixture format for tests.
- The movement cost is **injected**: a function `(unit AP per metre, movement class or profile, terrain type, signed slope) → AP per metre, or impassable`. Tests use fixture costs; M4 Issue 4 later provides the real one from `data/terrain.yaml`. M3 and M4 therefore do not depend on each other.

## Conventions
Same as M4 (`milestones/m4-rules-core.md`, "Conventions for all issues"): a package in the hawkbee workspace with its own repository (stack decision 7), language and tools from M2, 100 % line coverage target, deterministic, immutable models, rule IDs in test names, and no guessing (open a question in `specs/95-open-questions.md`).

---

## Issue 1: Project scaffold
Label: `infra`
Rules: none (setup).

Create the pathfinding project like M4 Issue 1.

Acceptance criteria:
- Tests and static analysis pass with one placeholder test.

## Issue 2: Navigation model
Label: `map`
Rules: MAP-02, MAP-16, MAP-22, MAP-23, MAP-36, MAP-37.
Depends on: 1.

A navigation model built from the map format chosen in M2:
- a grid of cells, each with a ground height and a terrain type; water cells for rivers and lakes;
- floating islands as separate surfaces, linked to the ground only by bridges and ladders;
- objects on cells (trees, buildings, walls) and constructions (bridges, reinforced bridges, ladders, roads).

The signed slope between two neighbour cells comes from their heights (positive uphill). A small text or YAML fixture format builds test maps; it is a test tool, not the game's map format.

Acceptance criteria:
- Fixture maps with a river, a forest, a town, a mountain and a floating island load into the model.
- Slope tests: uphill positive, downhill negative.

## Issue 3: Paths for units
Label: `search`
Rules: COMBAT-03, MAP-11 to MAP-19, MAP-22 to MAP-25, MAP-36, MAP-37, UNIT-01, UNIT-02.
Depends on: 2.

- Cheapest path in AP from A to B for a movement class (foot, wheeled, tracked) or profile (flying, sail), using the injected cost. Impassable terrain and slopes steeper than the class maximum, up or down, are avoided (decision 133).
- Ladders are for foot units; bridges for every ground class; boats stay on water; amphibious units switch between their ground class and `sail`; flying units ignore ground terrain and stay under the altitude limit (MAP-17).
- "No path" is a valid answer: the unit is stranded (MAP-37).
- Output: the path as samples for M4 Issue 4.

Acceptance criteria:
- Table-driven tests per class and profile on fixture maps: impassable cases, the slope limit both ways, a ladder climbed by foot units only, a boat crossing, an amphibious crossing, a flyer over a mountain.
- The cost of a returned path equals the sum of its samples under the injected cost.

## Issue 4: Paths for relics and HQs
Label: `search`
Rules: RELIC-19, RELIC-20, RELIC-21, RELIC-22, RELIC-26, RELIC-28, HQ-11, HQ-14, HQ-48.
Depends on: 3.

- Relics and HQs cannot fly, and cannot cross water (except on reinforced bridges), forests, towns, mountains or walls.
- A relic or an HQ can go over the edge of a floating island and fall (RELIC-22, HQ-48).
- A walled-in relic has no path until a wall is destroyed (RELIC-28).
- The cost is the injected one with the `push` profile; the AP per metre is `push.pot_ap_per_m` for a relic and `hq.ap_per_m` for an HQ (decisions 175, 177). The profile's slope limit applies uphill and downhill.

Acceptance criteria:
- A relic crosses a reinforced bridge but not a normal one, avoids forests and towns, has no path when walled in, takes a road rather than mud, is blocked by a slope steeper than the `push` limit up or down, and falls from an island edge; an HQ falls too.

## Issue 5: World changes
Label: `delta`
Rules: MAP-06, MAP-07, MAP-09, MAP-28, MAP-37.
Depends on: 3.

- Paths follow the changes of a battle (the delta layer): bridges, ladders, roads and walls built; trees, buildings, walls and bridges destroyed; craters, which change heights and slopes: each is an entry (centre, radius, depth) sampled on the cells it covers (stack decision 5).
- A change updates only the part of the search data it touches.

Acceptance criteria:
- Building a bridge opens a path; destroying it strands the units on the far side; a crater changes the slope of a path.
- Paths after an update are the same as paths computed from scratch on the changed map.

## Issue 6: Long paths on big maps
Label: `performance`
Rules: MAP-04.
Depends on: 3, 5.

- Paths across a 10 × 50 km map for hundreds of units (hierarchical search or another method).
- A benchmark on a synthetic map of that size records time and memory per path. The budget itself is set with the technical stack (M2).

Acceptance criteria:
- The benchmark runs from the command line and its results are committed.
- On test maps, paths from the fast method cost at most a stated margin (for example 10 %) more AP than the exact search.
