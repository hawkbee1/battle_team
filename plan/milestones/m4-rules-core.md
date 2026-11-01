# Milestone 4: headless rules core

Goal: a headless rules core that loads `plan/data/*.yaml` and resolves AP, movement, vision and combat exactly as the specs say, covered by unit tests. **No rendering, no network.** Stack from M2 (`stack/01-simulation-host.md`): Dart, in the package `battle_rules` (its own repository, hawkbee `packages/battle_rules`, stack decision 7).

Each issue below is ready to be created as a GitHub issue in the milestone "M4 – Rules core". Labels: `rules-core` plus the one listed. Every issue names the spec rules it implements; code and tests cite those IDs in comments and test names (for example a test named `COMBAT-06 moves at regen speed at 0 AP`).

## Conventions for all issues
- **Repositories (stack decision 7)**: each package lives in the hawkbee workspace `packages/` folder, in its own public repository `hawkbee1/<name>` added to hawkbee as a git submodule. Procedure: hawkbee `docs/dart_code_3d/agent-workflow.md`, section 2.
- **Language and layout (M2)**: Dart. `battle_rules` is a pure Dart package with no Flutter import, so the host and the client both use it. Tests with `package:test`, lints with `very_good_analysis`, coverage with `very_good test --coverage`. 100 % line coverage target.
- **Numbers only in YAML.** No game number is written in code or tests except inside test fixtures. Tests on real values read them from `apps/battle_team/plan/data/*.yaml` in the hawkbee checkout; `battle_rules` takes the YAML text from its caller (stack decision 7). When a value is tuned, the tests that use it are updated in the same change.
- **Deterministic.** Time is passed in (no wall clock); randomness comes from an injected seeded RNG.
- Immutable models, no global state.
- A rule that seems unclear or contradictory is not guessed: open a question in `plan/specs/95-open-questions.md` and link it in the issue.

---

## Issue 1: Project scaffold
Label: `infra`
Rules: none (setup).

Create the rules-core project with the language, layout and tools chosen in M2, with no rendering or UI dependency.

Acceptance criteria:
- Tests and static analysis pass with one placeholder test.
- The server and the client can use the rules core without pulling a UI framework into it.
- Its README says how to run the tests and points to `plan/`.

## Issue 2: Load and validate the data files
Label: `data`
Rules: COMBAT-10, COMBAT-20, COMBAT-22, COMBAT-23, COMBAT-50, UNIT-03, UNIT-17, UNIT-23, UNIT-38, MAP-15, MAP-21, MAP-35, MAP-40.
Depends on: 1.

Typed, immutable models for `units.yaml`, `combat.yaml`, `terrain.yaml`, `battle.yaml`, `economy.yaml`, `medals.yaml`, and a loader that takes a directory path.

Validation (fail with a clear message naming file, key and value):
- every unit `armor_type` is in `armor_types`; every `weapons.default` is null (unarmed unit, `allowed: []`) or in its `allowed` list; every allowed weapon exists in `weapon_types`;
- every weapon has a row in `multipliers` with every armor type; `hit_chance.size_factor` covers every armor type;
- every terrain `ap_multiplier` covers `foot`, `wheeled`, `tracked`, `flying`, `sail`, `push`; every movement class and profile has a `slope` entry; every unit has an `ap_per_m`, and `ap_max` is 30; every unit and the HQ have a `hit_box_m`; every weapon except artillery and the explosive charge has a `projectile_speed_mps`; a flying unit's base `move_speed` is at most the jeep's and a sailing unit's at most the tank's (decisions 174, 178);
- `commander_levels.section_xp` has `max_level` values, in increasing order;
- every terrain object has an `armor_type` in `armor_types`;
- every action in a unit's `actions` is known (`capture`, `push`, `build`, `repair`, `heal`, `observe`) and its up-front AP is at most the unit's `ap_max` (decision 132).

Acceptance criteria:
- The current `plan/data/*.yaml` load without error (test reads the real files, so data and code cannot drift silently).
- One fixture per validation rule proves the error message.

## Issue 3: Simulation clock and AP pool
Label: `ap`
Rules: COMBAT-01, COMBAT-02, COMBAT-04, COMBAT-05, COMBAT-06, MAP-20, HQ-34, UNIT-38.
Depends on: 2.

- AP recover at the battle's `ap.recovery_per_hour` (1 by default) up to `ap_max` (30), whatever the unit does (also while stored).
- Spending: a paid action (shot, role action, pick-up) that the unit can do **waits** until the unit has enough AP and never goes negative. An action the unit cannot do (not in its `actions`) is refused.
- Movement at 0 AP continues at the speed the AP recovery allows (the battle's rate).
- Time-only actions (reload, unload, swap, land, take off) never touch AP.

Acceptance criteria:
- Test from the spec: an infantry unit (1 AP per metre) moving on grass covers 30 m, then moves 1 m per hour.
- Property test: AP stays within `[0, ap_max]` for any sequence of actions and time steps.

## Issue 4: Movement cost
Label: `movement`
Rules: COMBAT-03, MAP-11, MAP-12, MAP-13, MAP-14, MAP-15, MAP-16, MAP-17, MAP-18, MAP-19, MAP-22, MAP-23, UNIT-01, UNIT-02.
Depends on: 2.

- AP cost of moving a unit along a path given as samples `(terrain type, slope degrees, length m)`.
- Cost per metre: the unit's `ap_per_m` × the `ap_multiplier` of (movement class or profile, terrain) × `max(min_multiplier, 1 + slope × factor)`, with a **signed** slope (positive uphill, decision 133); impassable when the table says `null` or the slope, up or down, is steeper than `max_degrees`.
- Time along a path: its length ÷ `move_speed`, on any terrain and slope (decision 180); with no AP left, the unit moves as fast as its AP come back (COMBAT-06).
- Profiles: `flying` (while flying), `sail` (water), `push` (a pushed relic or the moving HQ, decisions 175, 177); a landed flyer uses its ground class; a unit with `sail` and a ground class (amphibious) uses whichever fits the terrain; a boat (sail, no ground class) cannot enter land.

Acceptance criteria:
- Table-driven tests for every movement class on every terrain, including impassable cases and the slope limit, uphill and downhill, and the downhill floor. Units with different `ap_per_m` (infantry, tank, jeep).
- Boat, amphibious and helicopter (flying and landed) cases.

## Issue 5: Vision
Label: `vision`
Rules: COMBAT-11, MAP-26, MAP-27, MAP-28, MAP-29, MAP-30, MAP-31, MAP-32, MAP-33, MAP-34, MAP-35, UNIT-34.
Depends on: 2.

Input is an abstract sight line (no 3D engine): observer vision range and terrain, weather, height difference, metres of forest crossed, and whether a hard blocker (mountain, intact building) is on the line.

- `effective vision = vision_range × weather factor × terrain factor + height bonus (capped) − forest metres × forest_vision_cost_per_m`.
- A target is seen when it is within effective vision and no hard blocker remains; destroyed objects never block.
- Scout `observe` adds its vision bonus for its duration and forbids moving.

Acceptance criteria:
- Tests per factor and combined; a flying observer (shorter forest crossing) sees a forest target a ground observer cannot.

## Issue 6: Weapons and firing cycle
Label: `combat`
Rules: COMBAT-04, COMBAT-05, COMBAT-13, COMBAT-26, COMBAT-27, COMBAT-28, COMBAT-29, COMBAT-30, COMBAT-31, COMBAT-32, COMBAT-33, COMBAT-56, UNIT-03, UNIT-04.
Depends on: 3.

- One weapon slot; equip or swap only while stored or next to the storage place; only allowed weapon types; a swap takes `weapon_swap.time_s`.
- Firing respects `rate_of_fire_rpm`, `magazine_capacity`, `ap_per_shot`; reload always gives a full magazine and discards what was left; unload; `move_while_loaded: false` forbids moving while loaded.
- A unit without weapon cannot attack.
- Killed unit drops its weapon; any unit allowed to use it can pick it up for `pickup_ap`, dropping its own; dropped weapons vanish after `despawn_after_s`.
- A 1-round weapon fires once per `reload_time_s` (COMBAT-56). Bought and swapped-out weapons wait in the section's storage (decision 151).

Acceptance criteria:
- Timeline tests (e.g. artillery must unload before moving; MG empties a magazine at its rate of fire).

## Issue 7: Hit chance under orders/AI and first-person spread
Label: `combat`
Rules: COMBAT-12, COMBAT-14, COMBAT-15, COMBAT-16, COMBAT-17, COMBAT-18, COMBAT-19, COMBAT-49, COMBAT-53.
Depends on: 5, 6.

- `chance = base_accuracy × (1 + (attack − defense)/100) × distance × cover × size × speed × morale factors (× indirect factor)`, clamped to `[min, max]`; full cover (factor 0) still gets the minimum (decision 135).
- Indirect fire (artillery) may target a ground position seen by its section or relayed by a radio; other weapons need the unit's own sight. The engineer's explosive charge never misses (COMBAT-55).
- A missed artillery shot lands in a random direction from the aimed point, at `miss_scatter.max_m` × `(roll − chance) / (1 − chance)`. The landing point stays within `range_m` of the artillery: a point beyond it is moved back toward the artillery to `range_m` (decision 154). Splash damage does not depend on `range_m`.
- First-person (decision 183): the order gives the aim direction and the fire time. The rules core deviates the direction by the spread (`aim` values, tightened by `attack`, scaled by morale) with the seeded RNG, flies the projectile at `projectile_speed_mps`, and returns the first hit volume (`hit_box_m`) or obstacle on its path. Obstacles come from an injected query (terrain and objects), as sight lines do in Issue 5. The client only draws the projectile (stack decision 8).
- Hit roll uses the injected seeded RNG.

Acceptance criteria:
- Factor tests and clamp tests; a statistical test (fixed seed, 10,000 rolls) matches the computed chance within 1 %.
- First-person: a shot hits the first hit volume or obstacle on its path; a target that moves out of the line during the flight is missed; the same seed gives the same spread.

## Issue 8: Damage, friendly fire, transports
Label: `combat`
Rules: COMBAT-20, COMBAT-21, COMBAT-24, COMBAT-25, COMBAT-34, COMBAT-36, COMBAT-54, COMBAT-55, UNIT-37, MAP-40, HQ-16, HQ-22.
Depends on: 2.

- `damage = base_damage × multipliers[weapon][armor] × airborne_factor (flying target only)`; nothing else changes it.
- Friendly fire at full damage. Splash (bombard attacks, COMBAT-55): every unit within `splash_radius_m` of the impact point is hit at once, without its own roll, with damage falling off with the distance (`splash`).
- Units carried by a transport take `carried_damage_share` of each hit (with their own armor type) and `ejection_damage_share_of_max_hp` of their maximum HP when the transport is destroyed.
- Relics take no damage (multiplier 0).
- Terrain objects take damage through their `armor_type` (MAP-40).

Acceptance criteria:
- Tests for every weapon against every armor type read from the real table; flying target cases; carried units; splash falloff with distance.

## Issue 9: Morale and 0-HP outcomes
Label: `combat`
Rules: COMBAT-36, COMBAT-37, COMBAT-38, COMBAT-39, COMBAT-40, COMBAT-41, COMBAT-43, COMBAT-46, COMBAT-47, COMBAT-48, COMBAT-49, UNIT-39.
Depends on: 8.

- Morale 0–100, starts at base, changes only through events (aura per minute, nearby kills and ally deaths, outnumbered per minute); no drift.
- At 0 HP: death, unless the final blow comes from a commander on an **enemy** unit (decision 131); then `p(spared) = k × ((100 − morale)/100 + (1 − AP/ap_max)) / 2`; spared → defection or prisoner by `defection_share`; defection needs room in the attacking section (section size cap, UNIT-39), otherwise prisoner.
- A defector keeps XP, evolution and weapon; a prisoner keeps its weapon and goes to the captor's prisoner storage (unlimited).

Acceptance criteria:
- Spec examples: morale 20 and 10 % AP → 51 %; morale 50 and full AP → 15 %.
- Non-commander final blow always kills; a commander's final blow on an ally always kills.
- An enemy commander or a guild camp is never spared (decision 149).

## Issue 10: Role actions, pushing and interruption
Label: `actions`
Rules: COMBAT-07, COMBAT-08, COMBAT-09, UNIT-33, UNIT-35, UNIT-38, RELIC-05, RELIC-06, RELIC-07, RELIC-08, RELIC-09, RELIC-24, RELIC-25, RELIC-29, HQ-10, HQ-12, HQ-14.
Depends on: 3, 4.

- Build and repair: AP paid up front (the unit must have it), then a duration. Construction AP and time from `terrain.yaml` objects.
- Capture: a team pot of `pot_ap`, filled by units inside the radius with `contribution_ap` per action, as often as they like; the capture duration starts when the pot is full (decisions 170, 173). Values from `battle.yaml`.
- A partly filled pot keeps its AP until it is used up. A relic's push pot empties when another team captures the relic or when it falls from an island; a capture pot empties when an enemy enters the radius, even with no unit of its team inside (decisions 173, 176).
- Heal is instant: `heal_ap` restores `heal` HP. Heal and repair work on every friendly unit except the HQ (decision 139).
- Interrupted action: AP lost, progress kept, resuming costs the remaining part; **except** a capture interrupted by an enemy entering the radius, which loses its progress and its pot. Capture progress belongs to the team: another unit of the team can resume it (decision 140).
- Capture radius: every unit inside counts whatever its state; any enemy blocks.
- Push: at least `min_pushers` units that can push; the relic moves at `speed_m_per_h`; pushers add `contribution_ap` per action to the team push pot, and each metre pushed costs `pot_ap_per_m` from it × the ground and signed slope multipliers of the `push` profile (decision 175); an empty pot stops the relic, and the push stops while fewer than `min_pushers` push; with `min_pushers + n` pushers a relic crushes (kills) up to `n` units, otherwise it stops at them.
- HQ move: ordered by the manager, paid from the HQ's own AP (`hq` in `battle.yaml`) at `hq.ap_per_m` × the `push` profile, at `hq.speed_m_per_h`; with no AP it moves as fast as its AP come back (COMBAT-06); any unit in its path ends the order (decision 177).

Acceptance criteria:
- Tests for each action, both interruption cases, the capture block, a capture pot filled by several units, a capture resumed by another unit of the team, an empty push pot, a partly filled pot kept after the push stops, a push pot emptied by a capture and by a fall, a waiting capture pot emptied by an enemy entering the radius, the crush rule with 10, 11 and 13 pushers, an HQ draining its AP in mud, and an HQ move ended by a unit in its path.

## Issue 11: Scenario harness
Label: `tooling`
Rules: all of the above (integration).
Depends on: 3–10.

A command-line runner (`scenario <file>`) that plays a scripted scenario (units, positions as abstract distances, orders, seed, duration) and prints an event log and a summary (shots, hits, damage, deaths, AP used). Used to tune the placeholder numbers (decision 69).

Acceptance criteria:
- Three committed scenarios with expected summaries checked by tests: rifle squad vs jeep, artillery with radio-relayed target, relic push with crushing.

---

## Later milestones (outline, for the chosen stack)
- **M5 – Simulation host and persistence** (`battle_host` package, Dart, see `stack/01` and `stack/02`; the war, section and guild rules go in `battle_rules` so functions can call them, `stack/08`; errors reported to Sentry, `stack/06`): battle state in memory, write-ahead log and snapshots, log batches to Appwrite Storage, low-write data in Appwrite. World delta layer (MAP-06, MAP-08), storage and deployment (HQ-24 to HQ-47), economy (ECO), XP and progression (UNIT-05 to UNIT-43), relic ownership and victory timer (RELIC-10 to RELIC-18), section AI and API orders (AI-01 to AI-09), statistics and medals computed from the battle logs in batch (decision 143).
- **M6 – Networking** (`stack/03`): WebSocket for players, HTTPS for AI agents and the server, one command handler. Fog of war per section (MAP-29) filtered on the host, 5 Hz position updates, alerts (RELIC-10), late joiners get the delta layer (MAP-08).
- **M7 – Client** (`stack/04`, `stack/06`): flutter_scene for the 3D world, Flutter widgets for the interface, top-down and first-person control, pings, map markers and team chat (decision 123). Discord account linking (decision 126) through the bridge service. Starts with the rendering spike on the slowest target device.
- **M8 – Revision after real battles**: `milestones/m8-revision-after-real-battles.md`.
