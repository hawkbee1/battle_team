# Milestone 1: headless rules core

Goal: a pure Dart package that loads `plan/data/*.yaml` and resolves AP, movement, vision and combat exactly as the specs say, covered by unit tests. **No rendering, no network, no Flutter.**

Each issue below is ready to be created as a GitHub issue in the milestone "M1 – Rules core". Labels: `rules-core` plus the one listed. Every issue names the spec rules it implements; code and tests cite those IDs in comments and test names (for example `test('COMBAT-06 moves at regen speed at 0 AP', ...)`).

## Conventions for all issues
- Package: `packages/battle_team_rules/` in this repository, pure Dart (`dart test`), `very_good_analysis` lints, 100 % line coverage target.
- **Numbers only in YAML.** No game number is written in Dart code or tests except inside test fixtures. Tests on real values read them from `plan/data/*.yaml`.
- **Deterministic.** Time is passed in (no wall clock); randomness comes from an injected seeded RNG.
- Immutable models (`equatable`), no global state.
- A rule that seems unclear or contradictory is not guessed: open a question in `plan/specs/95-open-questions.md` and link it in the issue.

---

## Issue 1: Package scaffold
Label: `infra`
Rules: none (setup).

Create `packages/battle_team_rules/` (pure Dart, no Flutter dependency), register it in the pub workspace root `pubspec.yaml` (`workspace:` list), add `very_good_analysis`, `test`, `yaml`, `equatable`.

Acceptance criteria:
- `dart test` and `dart analyze` pass in the package with one placeholder test.
- The app (`battle_team`) can depend on the package (path or workspace dependency) without pulling Flutter into it.
- README of the package says how to run tests and points to `plan/`.

## Issue 2: Load and validate the data files
Label: `data`
Rules: COMBAT-10, COMBAT-20, COMBAT-22, COMBAT-23, COMBAT-50, UNIT-03, UNIT-17, UNIT-23, MAP-15, MAP-21, MAP-35.
Depends on: 1.

Typed, immutable models for `units.yaml`, `combat.yaml`, `terrain.yaml`, `battle.yaml`, `economy.yaml`, `medals.yaml`, and a loader that takes a directory path.

Validation (fail with a clear message naming file, key and value):
- every unit `armor_type` is in `armor_types`; every `weapons.default` is in its `allowed` list; every allowed weapon exists in `weapon_types`;
- every weapon has a row in `multipliers` with every armor type; `hit_chance.size_factor` covers every armor type;
- every terrain `ap_cost_per_m` covers `foot`, `wheeled`, `tracked`, `flying`, `sail`; every movement class and profile has a `slope` entry;
- `commander_levels` are sorted by `section_xp`.

Acceptance criteria:
- The current `plan/data/*.yaml` load without error (test reads the real files, so data and code cannot drift silently).
- One fixture per validation rule proves the error message.

## Issue 3: Simulation clock and AP pool
Label: `ap`
Rules: COMBAT-01, COMBAT-02, COMBAT-04, COMBAT-05, COMBAT-06, MAP-20, HQ-34.
Depends on: 2.

- AP regenerate at `ap_regen` per second up to `ap_max`, whatever the unit does (also while stored).
- Spending: a paid action (shot, role action, pick-up) **waits** until the unit has enough AP; it is never refused and never goes negative.
- Movement at 0 AP continues at the speed the regen allows.
- Time-only actions (reload, unload, swap, land, take off) never touch AP.

Acceptance criteria:
- Test from the spec: a soldier moving at 5 m/s on grass (1 AP/m, regen 1.5) empties its pool, then moves at 1.5 m/s.
- Property test: AP stays within `[0, ap_max]` for any sequence of actions and time steps.

## Issue 4: Movement cost
Label: `movement`
Rules: COMBAT-03, MAP-11, MAP-12, MAP-13, MAP-14, MAP-15, MAP-16, MAP-17, MAP-18, MAP-19, MAP-22, MAP-23, UNIT-01, UNIT-02.
Depends on: 2.

- AP cost of moving a unit along a path given as samples `(terrain type, slope degrees, length m)`.
- Cost per metre from the (movement class or profile, terrain) table × `1 + slope × factor`; impassable when the table says `null` or the slope is above `max_degrees`.
- Profiles: `flying` (while flying), `sail` (water); a landed flyer uses its ground class; a unit with `sail` and a ground class (amphibious) uses whichever fits the terrain; a boat (sail, no ground class) cannot enter land.

Acceptance criteria:
- Table-driven tests for every movement class on every terrain, including impassable cases and the slope limit.
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
Rules: COMBAT-04, COMBAT-05, COMBAT-13, COMBAT-26, COMBAT-27, COMBAT-28, COMBAT-29, COMBAT-30, COMBAT-31, COMBAT-32, COMBAT-33, UNIT-03, UNIT-04.
Depends on: 3.

- One weapon slot; equip or swap only while stored or next to the storage place; only allowed weapon types.
- Firing respects `rate_of_fire_rpm`, `magazine_capacity`, `ap_per_shot`; reload always gives a full magazine and discards what was left; unload; `move_while_loaded: false` forbids moving while loaded.
- A unit without weapon cannot attack.
- Killed unit drops its weapon; any unit allowed to use it can pick it up for `pickup_ap`, dropping its own; dropped weapons vanish after `despawn_after_s`.

Acceptance criteria:
- Timeline tests (e.g. artillery must unload before moving; MG empties a magazine at its rate of fire).

## Issue 7: Hit chance under orders/AI and first-person spread
Label: `combat`
Rules: COMBAT-12, COMBAT-14, COMBAT-15, COMBAT-16, COMBAT-17, COMBAT-18, COMBAT-19, COMBAT-49, COMBAT-53.
Depends on: 5, 6.

- `chance = base_accuracy × (1 + (attack − defense)/100) × distance × cover × size × speed × morale factors (× indirect factor)`, clamped to `[min, max]`.
- Indirect fire (artillery) may target a ground position seen by its section or relayed by a radio; other weapons need the unit's own sight.
- First-person: spread from `aim` values, tightened by `attack`, scaled by morale. The rules core only provides the spread value; projectile flight is the client's job.
- Hit roll uses the injected seeded RNG.

Acceptance criteria:
- Factor tests and clamp tests; a statistical test (fixed seed, 10,000 rolls) matches the computed chance within 1 %.

## Issue 8: Damage, friendly fire, transports
Label: `combat`
Rules: COMBAT-20, COMBAT-21, COMBAT-24, COMBAT-25, COMBAT-34, COMBAT-36, COMBAT-54, UNIT-37, HQ-16, HQ-22.
Depends on: 2.

- `damage = base_damage × multipliers[weapon][armor] × airborne_factor (flying target only)`; nothing else changes it.
- Friendly fire at full damage; splash damage to every unit within `splash_radius_m`.
- Units carried by a transport take `carried_damage_share` of each hit (with their own armor type) and ejection damage when the transport is destroyed.
- Relics take no damage (multiplier 0).

Acceptance criteria:
- Tests for every weapon against every armor type read from the real table; flying target cases; carried units.

## Issue 9: Morale and 0-HP outcomes
Label: `combat`
Rules: COMBAT-36, COMBAT-37, COMBAT-38, COMBAT-39, COMBAT-40, COMBAT-41, COMBAT-43, COMBAT-46, COMBAT-47, COMBAT-48, COMBAT-49.
Depends on: 8.

- Morale 0–100, starts at base, changes only through events (aura per minute, nearby kills and ally deaths, outnumbered per minute); no drift.
- At 0 HP: death, unless the final blow comes from a commander; then `p(spared) = k × ((100 − morale)/100 + (1 − AP/ap_max)) / 2`; spared → defection or prisoner by `defection_share`; defection needs room in the attacking section (section size cap), otherwise prisoner.
- A defector keeps XP, evolution and weapon; a prisoner keeps its weapon and goes to the captor's prisoner storage (unlimited).

Acceptance criteria:
- Spec examples: morale 20 and 10 % AP → 51 %; morale 50 and full AP → 15 %.
- Non-commander final blow always kills.

## Issue 10: Role actions, pushing and interruption
Label: `actions`
Rules: COMBAT-07, COMBAT-08, COMBAT-09, UNIT-35, RELIC-05, RELIC-06, RELIC-07, RELIC-08, RELIC-09, RELIC-24, RELIC-25, HQ-12, HQ-15.
Depends on: 3, 4.

- Build, repair, capture: AP paid up front (unit must have it), then a duration. Construction AP and time from `terrain.yaml` objects; capture values from `battle.yaml`.
- Heal is instant: `heal_ap` restores `heal` HP.
- Interrupted action: AP lost, progress kept, resuming costs the remaining part; **except** a capture interrupted by an enemy entering the radius, which loses its progress.
- Capture radius: every unit inside counts whatever its state; any enemy blocks.
- Push: at least `min_pushers`; each pusher pays `ap_per_m` × slope factor of its class; with `min_pushers + n` pushers a relic crushes up to `n` units, otherwise it stops at them; a pushed HQ never crushes.

Acceptance criteria:
- Tests for each action, both interruption cases, the capture block, and the crush rule with 10, 11 and 13 pushers.

## Issue 11: Scenario harness
Label: `tooling`
Rules: all of the above (integration).
Depends on: 3–10.

A command-line runner (`dart run battle_team_rules:scenario <file>`) that plays a scripted scenario (units, positions as abstract distances, orders, seed, duration) and prints an event log and a summary (shots, hits, damage, deaths, AP used). Used to tune the placeholder numbers (decision 69).

Acceptance criteria:
- Three committed scenarios with expected summaries checked by tests: rifle squad vs jeep, artillery with radio-relayed target, relic push with crushing.

---

## Later milestones (outline)
- **M2 – Server state and persistence**: battle state on the Appwrite backend, world delta layer (MAP-06, MAP-08), storage and deployment (HQ-24 to HQ-44), economy (ECO), XP and progression (UNIT-05 to UNIT-32), relic ownership and victory timer (RELIC-10 to RELIC-18).
- **M3 – Networking**: real-time orders, fog of war per section (MAP-29), alerts.
- **M4 – Client**: top-down and first-person control on Flame, pings and map markers (decision 123), Discord account linking (decision 126).
