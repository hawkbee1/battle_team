# Milestone 5: simulation host and persistence

Goal: a simulation host that runs whole battles in memory from orders, on the rules of M3 and M4, writes what it needs to survive a crash, and keeps the long-lived data (wars, sections, guilds, statistics, medals) in Appwrite. Players reach it through the network in M6; in this milestone orders come from tests, the scenario harness and the host's own sections. Stack from M2: `stack/01` (host), `stack/02` (persistence), `stack/05` (map format), `stack/06` (accounts, Sentry), `stack/07` (principles, packages), `stack/08` (what runs where).

Each issue below is one agent work session (hawkbee `docs/battle_team/`).

## Packages
| Package | What it holds | Created in |
|---|---|---|
| `battle_rules` | The rules of M4, plus XP, money, storage, victory, teams, wars and guilds. The war, section and guild rules live here so that Appwrite Functions can call them (stack decision 8). | M4 |
| `battle_map` | The map format, its loader and the map builder (stack decision 5). | Issue 8 |
| `battle_protocol` | Commands, events, the battle-log format and the API key format, shared by the host, the client and the functions. | Issue 9 |
| `battle_host` | The simulation host: battle state, the command handler, the delta layer, the write-ahead log, snapshots and the adapters to Appwrite and Sentry. A native executable. | Issue 10 |
| `battle_stats` | Statistics and medals computed from the battle logs (decision 143). | Issue 17 |

## Conventions
- Those of M4 (`milestones/m4-rules-core.md`, "Conventions for all issues"): one repository per package, 100 % line coverage, numbers only in `plan/data`, deterministic, immutable models, rule IDs in test names, no guessing.
- **New packages** follow the procedure of hawkbee `docs/dart_code_3d/agent-workflow.md` §2 with the template named in `stack/07`. The session creates the public repository `hawkbee1/<name>`.
- **Pure packages:** `battle_rules`, `battle_map`, `battle_protocol` and `battle_stats` do no I/O in `lib/`. Command-line tools in `bin/` read and write files.
- **The host** keeps its I/O in adapters behind the ports of `stack/07` (`Clock`, `SeededRandom`, `CommandSink`, `LogSink`, `SnapshotStore`, `ErrorReporter`). Its core is tested with fakes. Each port has one contract suite that every implementation passes, the in-memory one and the Appwrite one (Liskov). Tests that need the local Appwrite instance are tagged and opt-in.
- **Replay:** a battle replayed from its snapshot and its log reaches the same state as the live battle. Each host issue tests this for the orders it adds.
- **Errors** go through `ErrorReporter`; only the host and the functions hold the Sentry adapter (stack decision 6).
- **Functions** are adapters in hawkbee `backend/functions/<name>/` around a package, with a vendored copy of it (stack decision 8).
- A pattern named in `stack/07` is cited in the doc comment of the class that uses it.

---

## Issue 1: Effective stats and skill trees
Rules: UNIT-18 to UNIT-23, UNIT-36, COMBAT-52.
Package: `battle_rules`.

- A unit's bought tree nodes give its effective stats: each step adds `step_bonus` of the base value, up to `stat_cap_of_base` × base (`trees` in `data/units.yaml`). AP maximum and AP recovery never evolve (decision 167).
- Buying a node: step *n* needs step *n* − 1 and costs `cost_base` × *n* of the unit's own unspent XP. Nodes are permanent and never exclude each other.
- Role stats grow through the type's extra stats (`overrides`: relay range, aura radius, transport weight, heal).
- The M4 rules read effective stats instead of the base `UnitType` stats (deferred from M4.11): hit chance, vision, speed, heal, transport capacity, radio relay.

Acceptance criteria:
- 20 steps reach the ×3 cap; a 21st step, a step without its prerequisite and a step the unit's XP cannot pay are refused.
- An unevolved unit gives the M4 results unchanged; for each evolvable stat, a test shows the evolved value is used.
- An evolved helicopter can outrun a jeep that has not evolved (decision 178).

## Issue 2: XP, section XP and commander level
Rules: UNIT-05 to UNIT-11, UNIT-14 to UNIT-17, UNIT-39, UNIT-40, UNIT-43; decisions 197 to 199.
Package: `battle_rules`.

- XP for hits and kills, scaled by `1 + target XP / attacker XP` up to the cap, with earned XP; repeated XP from the same target or the same build spot (within `same_spot_radius_m`) within `diminishing.window_s` shrinks by `factor_per_repeat`; hitting allies gives none.
- XP for role actions and for captures (split by the AP each unit put into the pot, decision 179, with the contributions M4.10 records), and `victory_xp` for every unit of the winning team.
- `section_xp_share` of every XP point goes to the section. Section XP sets the commander level (`commander_levels`), which sets the section size cap and the number of units a section may own (`section_size`).

Acceptance criteria:
- Target scaling at, under and over the cap; the diminishing sequence within the window and its reset after it; no XP for a friendly hit.
- A capture pot filled 30/20 by two units pays them 30 and 20 XP with the defaults, a dead contributor included; a lost pot pays nothing.
- The cap at levels 1, 5, 6 and 60; a section at its cap owns at most 2 × cap units.

## Issue 3: Money
Rules: ECO-01 to ECO-06, ECO-08 to ECO-22, SOC-10 to SOC-15, COMBAT-27, UNIT-27, UNIT-41, HQ-04, HQ-43; decisions 200 to 203.
Package: `battle_rules`.
Depends on: 2.

- A section's wallet, in w€. Earnings for the acting unit's section (`earnings` in `economy.yaml`).
- Purchases: units, radios and weapons at their price (`prices`, default for anything unlisted); the guild camp by the guild chief only. A unit needs free room in the section (Issue 2).
- Transfers between sections of one team only, with the guild or the outside fee; fees are destroyed.
- The safety net: when a commander dies or loses all his units, his money becomes `max(money, war min_starting_money)`. A new section starts with that amount.

Acceptance criteria:
- Each earning; a purchase refused for lack of money, of room, or of the chief's role; a transfer to another team refused; both fees, and the money they destroy.
- The safety net after a commander's death and after the loss of the last unit, and not otherwise.

## Issue 4: Storage, deployment and the commander's death
Rules: HQ-02, HQ-03, HQ-13, HQ-24 to HQ-42, HQ-44, HQ-46, HQ-47, HQ-49, ECO-07, UNIT-28, UNIT-29, UNIT-42, COMBAT-44, COMBAT-45, COMBAT-51; decisions 204 to 207.
Package: `battle_rules`.
Depends on: 2, 3.

- Where a unit is, as a State (stack decision 7): on the field, carried, stored, prisoner. The guild camp and the HQ are never stored.
- The storage place: the guild camp, or the HQ when the section has no guild or the guild no camp. A unit within `store_radius_m` is stored at once; elsewhere a recall takes `recall_s` and nothing stops it.
- Deploying costs `deploy_ap`, next to the storage place; an enemy within `deploy_block_radius_m` blocks it, and a blocked camp gives no fallback to the HQ. The last unit to leave the field, stored, recalled, killed, captured or defected, locks the section for `section_redeploy_lock_s` (decision 204); a storage forced by the commander's death does not. A loaded transport is not stored (HQ-49); a blocked or locked arrival refuses the purchase (decision 205).
- The commander's death: he resurrects at once in storage, loses `xp_loss_share` of his unspent XP (never his level), and every unit of his section on the field, carried ones included, is stored at once with the AP and morale losses of `commander_death`.
- Prisoners: an unlimited prisoner storage; exchange and ransom offers between section owners, the ransom going entirely to the captor section; a released prisoner returns to its owner's storage.

Acceptance criteria:
- Storing at 10 m, a recall completed after 6 hours while the unit is under fire, a unit killed during its recall.
- A deployment blocked by an enemy at 20 m, with no fallback to the HQ; the 24-hour lock after a full storage by choice, and none after a commander's death.
- A commander's death with a carried unit in the section; an exchange and a ransom.

## Issue 5: Relic ownership and victory
Rules: RELIC-10 to RELIC-18, RELIC-26, RELIC-27, HQ-18, HQ-19, HQ-20, HQ-23, HQ-45; decision 208.
Package: `battle_rules`.
Depends on: 4.

- A capture completed (M4.10) changes the relic's owner at once and tells the previous owner (the alert of RELIC-10; M6 delivers it). No protection time.
- The victory timer: a team that owns `victory.relics_to_hold` relics for `victory.hold_s` wins; the timer resets fully when it drops below, even for a moment. Its countdown is part of the state the clients will see.
- A relic lost with a destroyed reinforced bridge leaves the battle; with fewer relics left than `relics_to_hold`, only the HQ victory remains.
- Elimination: a destroyed HQ, or one lost with a bridge, eliminates its team; its units on the field are stored, its guild camps included (decision 208), its stored units stay. The last HQ standing wins.

Acceptance criteria:
- A 24-hour hold that wins; one that drops to 4 relics for one second and starts again from zero.
- Three teams, two eliminated one after the other; a battle where 4 relics remain and only the HQ victory is possible.

## Issue 6: Teams, newcomers and the HQ manager
Rules: SOC-01 to SOC-09, SOC-20, SOC-29, SOC-30, HQ-05 to HQ-08, UNIT-12, UNIT-13; decisions 209 to 211.
Package: `battle_rules`.
Depends on: 2.

- Team power is unit XP plus section XP. At each battle start, teams are formed balanced by power, `teams.count` of them, with each guild's sections kept together (decision 103). The balancing method is a code choice: document it and its worst case.
- A newcomer joins the team of lowest power and is offered 4 guilds at random among those that opted in, filled with others when fewer opted in; a team with fewer than 4 guilds shows them all. The draw uses the injected seeded random.
- The HQ manager: the player with the most medal points (bronze 1, silver 3, gold 10), on a tie the one whose commander has the most XP. The first player of the team to log in to the battle, then any player who logs in ranking above him; otherwise it changes only by delegation; no fallback when he is offline (decision 220).

Acceptance criteria:
- Balancing with a guild larger than an even share; 2 and 5 teams.
- The four guild cases of SOC-03 and SOC-07; the manager on a points tie.

## Issue 7: Wars, sections and guilds
Rules: SOC-13, SOC-16 to SOC-19, SOC-21, SOC-40 to SOC-53, UNIT-24, UNIT-30, UNIT-31, UNIT-32; decisions 212 to 215.
Package: `battle_rules`.
Depends on: 6.

- A war is a series of battles with its settings (`min_starting_money` among them); it ends when no battle is planned; it has no winner.
- A player has one commander per war, several wars at a time, and one commander per battle. A section belongs to one commander and one war; a player's sections share nothing.
- Between battles of a war a section keeps its units, XP, evolution, weapons, money and prisoners; each battle starts with full AP and HP and base morale. The end of the war loses everything but logs, statistics, medals and cosmetics.
- Guilds: created by a section without a guild whose commander is at `guild_creation_min_level`; roles chief, member and trainee; the chief hands over the role or disbands the guild and cannot leave; the chief accepts or refuses a trainee; a guild opts in or out of the newcomer list; the guild level, from the XP its sections earned while in it, sets its maximum size (`progression.guild_size`, decision 221).

Acceptance criteria:
- A section carried through three battles of a war, and lost at its end.
- Each guild action, refused where the rules say so; a trainee refused by the chief (decision 153).

## Issue 8: Map format and loader
Rules: MAP-01 to MAP-05, MAP-10, MAP-36, MAP-40, MAP-48, RELIC-02, HQ-01; decisions 216 to 218.
Package: `battle_map` (new, `dart_package`).

- The tiles of stack decision 5: 256 × 256 cells of 10 m, with a 16-bit height image, an indexed terrain image and `objects.yaml` (trees, buildings, walls, roads, bridges, ladders, floating islands). A map file lists its tiles, the team counts it supports, the HQ starting points for each count and the relics' starting positions.
- One loader (Factory Method): it gives the host's data now, the client's meshes in M7. Host data: the `NavigationMap` of `battle_pathfinding`, and the objects with their HP and armour type.
- The map builder (`bin/`): checks what stack decision 5 lists (terrain and armour types exist, bridges and ladders link land to land, islands are linked only by bridges and ladders, no object on a cell it cannot occupy), plus relics on solid ground and starting points for every supported team count; then writes the tiles.
- Image decoding through a package whose licence passes `packages_check_licenses`.

Acceptance criteria:
- A small committed test map is built, loaded and gives the expected `NavigationMap`.
- One failing fixture per builder check, with a message naming the tile, the cell or the object.
- The memory of one loaded 10 × 50 km synthetic map is measured (stack decision 1 estimates about 20 MB plus 15 MB of objects).

## Issue 9: Commands, events and the battle log
Rules: AI-05; decisions 162, 166, 183.
Package: `battle_protocol` (new, `dart_package`).

- Every order is a sealed `Command` (Command pattern) with its sender (account, section), its origin (player, AI, server), the sender's time, and the sequence number the host gives it. The list comes from the specs: moves (with an optional client path, stack decision 8), shots (target, or aim direction and fire time), reloads, weapon swaps and pick-ups, landing and take-off, loading and unloading, role actions, capture and push contributions, HQ moves, storage, recall, deployment, purchases, transfers, tree nodes, prisoner offers, and the HQ manager's delegation.
- Outcomes are sealed `BattleEvent`s. An attack's outcome (hit or miss, damage, kill) is in the same log entry as the attack, so statistics need no replay (stack decision 2).
- The battle-log format is a data contract, versioned from the start. Two encodings: compact binary for the log and the socket, JSON for HTTPS calls.
- The API key format: generated by the server, shown once, stored as a hash (stack decision 6).

Acceptance criteria:
- Every command and event round-trips through both encodings.
- Committed encoded samples freeze version 1 of the format: a change that breaks them fails the tests.

## Issue 10: Host scaffold, battle state and clock
Rules: COMBAT-01, COMBAT-02, UNIT-31; decisions 2 to 4; stack decisions 1, 6, 7.
Package: `battle_host` (new, `dart_cli`).
Depends on: 1, 8, 9.

- Battle state in memory: units with their state at the last update and their rates (AP, morale), sections, teams, relics, the HQs, pots and timers. A 1 Hz tick handles only what needs it (combat, vision, timers); idle units cost nothing. Timers run from seconds to days.
- One process holds several battles; one copy of a map serves all its battles (Flyweight). The search data of `battle_pathfinding` is shared between movers of a map (deferred from M3.6: one `GroundSearch` per mover holds about 135 MB at 5 million cells).
- The shared definitions of `plan/data` are kept apart from each battle's settings, which an admin chooses (decision 172; deferred from M4.11).
- A battle starts from a map and a setup: HQs at their starting points, relics in place, sections with full AP and HP and base morale.
- `ErrorReporter` with a fake for tests and a Sentry adapter.

Acceptance criteria:
- Two battles on one map share its copy; a battle advanced by the injected clock gives the lazy AP of COMBAT-02 for every unit.
- The process starts, loads a map and runs a battle with no order for a simulated day.

## Issue 11: Orders for movement and combat
Rules: AI-01, AI-02, AI-03, MAP-38, RELIC-27, HQ-07, HQ-09, HQ-10, HQ-12, HQ-17; decisions 156, 157, 183, 220; stack decision 8.
Package: `battle_host`.
Depends on: 10.

- One command handler for every sender (Facade). Checks in a Chain of Responsibility: sender, right to act (own section; the HQ manager for HQ moves), rules, AP. Origin tagging and logging around it (Decorator). A rate limit per sender, the same for players and AI agents.
- The M4 orders: moves with the client's path checked cell by cell, or searched when absent; shots (vision, rate of fire, hit chance with the injected random; first-person shots flown and traced on the host); reloads, swaps and pick-ups; landing and take-off with their times (deferred from M4.11); loading and unloading; role actions; capture and push contributions; HQ moves; interruptions.
- An order that waits for AP is checked again on the state at the time the wait ends, not at the time it was given (deferred from M4.11).
- One sealed refusal type for the whole chain, replacing the three refusal enums of M4 (deferred from M4.11).
- No order, no action: player units never act on their own; an offline player's units stay passive.
- A player logging in to the battle is a logged command from the server: the first of his team becomes HQ manager, a later one takes the role if he ranks above the current manager (decision 220).

Acceptance criteria:
- Each check refuses at its link with its refusal; a refused order changes nothing.
- A waiting heal whose target died before the wait ends is refused when it ends.
- A replay of a battle with each M4 order reaches the live state.

## Issue 12: Orders for storage, money, XP and prisoners
Rules: those of Issues 1 to 4 as orders: UNIT-18, UNIT-27, UNIT-29, ECO-04 to ECO-10, HQ-31 to HQ-36, HQ-46, COMBAT-44, SOC-09.
Package: `battle_host`.
Depends on: 3, 4, 11.

- Orders: store, recall, deploy, buy a unit, a weapon or the guild camp, transfer money, buy a tree node, offer, accept or refuse an exchange or a ransom.
- XP and money earned on the events that give them (hits, kills, constructions, heals, captures, HQ hits and destruction).
- The commander's death applied to his section; the safety net.

Acceptance criteria:
- A section that buys, deploys, fights, stores itself and is locked for 24 hours, replayed to the same state.
- A commander killed with units on the field and in a transport.

## Issue 13: Relics, victory and the end of a battle
Rules: RELIC-10 to RELIC-18, RELIC-22, RELIC-26, HQ-18 to HQ-20, HQ-23, HQ-45, HQ-48, UNIT-11.
Package: `battle_host`.
Depends on: 5, 11.

- Capture timers, owner changes and their alerts, the victory timer, eliminations.
- A relic or the HQ that falls from an island kills the units it lands on (decision 138); a destroyed bridge loses the relic or the HQ on it.
- The end of a battle: an event with the result (winning team, eliminations), which the `end_battle` function reads (Issue 18), and `victory_xp` paid.

Acceptance criteria:
- A battle won by the relic timer and one won by the last HQ, each replayed to the same result.

## Issue 14: World delta layer
Rules: MAP-06 to MAP-10, MAP-28, MAP-37, MAP-46.
Package: `battle_host`.
Depends on: 11.

- The delta layer on top of the authored map: constructions built, objects damaged and destroyed (HP from `terrain.yaml`), craters from weapons with the 20 m depth cap. Each change updates the paths (`LivePathfinder`), the sight lines and the shot tracing.
- It is part of the snapshot, and a late joiner can be sent it whole (MAP-08; delivered in M6).
- Deferred from M3.6: objects and constructions copied on each change, and unreachable goals that widen the corridor to the whole ground (connected-component labels).

Acceptance criteria:
- A tree destroyed by fire, a wall built, a crater dug: each changes a path and a sight line, and a replay gives the same layer.
- P-07 on the host: a change applied in under 10 ms.

## Issue 15: Write-ahead log, snapshots and recovery
Rules: decisions 3, 143, 162, 166; stack decision 2.
Package: `battle_host`.
Depends on: 11.

- An order is appended to the local write-ahead log and synced to disk before it is acknowledged.
- Every 10 seconds with new entries, one compressed batch goes to Appwrite Storage; an interval with none uploads nothing. Every 5 minutes, a snapshot (Memento) goes there too.
- Recovery: the latest snapshot, then the uploaded and local logs after it.
- `LogSink` and `SnapshotStore`: in-memory and Appwrite implementations pass one contract suite. Appwrite is the local instance in development.

Acceptance criteria:
- A host stopped at random points of a scripted battle recovers to the state of a host that never stopped.
- No order is acknowledged before it is on disk.
- P-03: bytes per event, events per second and upload size per batch, measured on the scripted battle.

## Issue 16: Server-managed sections
Rules: AI-06 to AI-09; decisions 159, 160, 163 to 166, 196.
Package: `battle_host`.
Depends on: 11.

- The server creates sections that look like any other and can do everything a player's section can.
- Every 30 minutes, each of their units that sees an enemy within its weapon's range fires with the chance of `server_managed` in `data/battle.yaml` (50 %, decision 196), the same at each check; the shot follows the normal rules.
- Their orders go through the same command handler as AI agents', with the origin `server`. The engine that decides their other orders is a later phase (decision 165).

Acceptance criteria:
- The fire check runs at the interval and not when an enemy enters range; a seeded run fires the expected shots; every server order is logged with the origin `server`.

## Issue 17: Statistics and medals
Rules: SOC-22, SOC-24, SOC-25, SOC-26, SOC-29, COMBAT-35; decision 143.
Package: `battle_stats` (new, `dart_package`), and the `daily_stats` function.
Depends on: 9.

- From a battle-day of log batches: statistics per unit, section and player, for the war and for the game; kills by target type, friendly kills included, and actions by kind.
- Medals at the thresholds of `medals.yaml`: war medals attached to their war, game medals on the account; medal points.
- Hit rates far above the norm are flagged for the moderation tools of M8 (stack decision 8).
- `daily_stats`: a daily cron function, an adapter that reads the batches, calls the package and writes the results to Appwrite.

Acceptance criteria:
- Statistics of a committed log fixture match the expected values; each medal tier is reached at its threshold.

## Issue 18: Appwrite data and functions around battles
Rules: SOC-16, SOC-17, SOC-20, AI-04; decisions 158, 161; stack decisions 2, 6, 8.
Packages: hawkbee `backend/`, `hawkbee_schema`, functions.
Depends on: 7, 13.

- Tables for the low-write data: commanders of an account, wars, battles, sections, guilds, purchases, medal definitions and results, API keys (hashed), admin roles. IDs and row models in `hawkbee_schema`.
- Functions, each an adapter around `battle_rules` or `battle_protocol`: `create_war` and `create_battle` (admins; teams of Issue 6), `end_battle` (on the end-of-battle event; carry-over of Issue 7), `guild_requests` (between battles), `api_keys` (create, shown once; revoke by the user or an admin).
- Check on the local instance the facts `stack/08` marks "to verify" (the 30-second limit of synchronous executions).

Acceptance criteria:
- A war created, a battle set up, ended and carried over to the next, on the local instance, by an opt-in test.
- A revoked key is refused at once.

## Issue 19: Load test and hosting
Rules: none new; P-01, P-02, P-03; stack decision 1 (hosting).
Package: `battle_host`.
Depends on: 12 to 16.

- One 1,000-unit battle over one simulated day, scripted with the scenario harness of M4.11 at that scale: CPU per tick at peak and on average, memory per battle and per map, battles per process (P-02); log volume (P-03); P-01 again with the search data shared between movers.
- A Docker image of the AOT-compiled host, run next to the local Appwrite. Battle placement (which container hosts which battle) is recorded. The live provider is the designer's choice before this session (stack decision 1).

Acceptance criteria:
- P-02 and P-03 results committed in `performance-tests.md` format; the stack estimates replaced by measurements.

## Issue 20: First map from real data
Rules: MAP-01, MAP-02, MAP-04; stack decision 5 (authoring).
Package: `battle_map`.
Depends on: 8.

- The builder makes a first map from real data: elevation from IGN RGE ALTI in France or Copernicus elsewhere, terrain types and roads from OpenStreetMap land cover. The map is then corrected by hand and checked by the builder.
- The licences of the sources (ODbL, Licence Ouverte, Copernicus DEM) are checked and their attributions written with the map.

Acceptance criteria:
- One real 10 × 50 km area turned into tiles that pass the builder's checks and load in the host.

---

Parallel: Issues 1, 2, 8 and 9 start together; 3, 6 after 2; 4 after 3; 5 after 4; 7 after 6; 10 after 1, 8 and 9; 12 to 16 after 11; 17 after 9; 20 after 8. Two sessions of one package rebase on `main` before opening their PR.
