# Milestone 7: client

Goal: a player plays the battle of M6 in the app, and the designer has pictures and video to show. The app signs the player in, opens into the 3D battle, and sends orders through `battle_client`; the host decides everything, as before. The milestone is built **from the playtest** (hawkbee `docs/battle_team/playtest.md`), by steps the designer can see: behaviour first, optimization only from the measurements of Issue 13 (designer, 2026-11-09). The first versions use only part of what the backend offers; what the interface does not show yet stays host-side, unchanged. Stack from M2: `stack/04` (rendering, frame budget, devices), `stack/03` (updates, interpolation, clock sync), `stack/06` (accounts), `stack/08` (what the client computes, client trust), `stack/07` (principles).

Each issue below is one agent work session (hawkbee `docs/battle_team/`).

## Packages
| Package | What it gains | Created in |
|---|---|---|
| `battle_team` (the app) | The battle screen grown from the playtest, accounts, orders, fog, chat. | — |
| `battle_client` | The order pre-check for display (stack decision 8), logging. | M6 |
| `battle_rules`, `battle_host` | The AP recovery delay (decision 238), the test unit (decision 239), the chat and ping messages. | M3, M5 |
| `battle_protocol` | Pings, map markers, team chat (Issue 10). | M5 |

## Conventions
- Those of M5 and M6 (`milestones/m5-simulation-host.md`, `milestones/m6-networking.md`): one repository per package, 100 % line coverage, numbers only in `plan/data`, rule IDs in test names, ports and adapters, sizes against estimates for new messages, nothing hidden leaves the host, a client is never trusted.
- **SOLID, with the Gang of Four patterns named.** Benchmarks come after behaviour (Issue 13), so every seam a measurement might change — how units and terrain are drawn, interpolation, the transport — is behind an abstraction (Strategy, Factory, Observer, Adapter…), the pattern named in the doc comment. Swapping an implementation after a benchmark must not touch its callers.
- **The client never decides rules** (decision 3, stack decision 8). It pre-checks orders with `battle_rules` only to display costs and refusals early; the host's answer wins.
- **Nothing the section does not see reaches the screen or the client's logs** (decision 237). Each issue that draws or logs new state proves it with a test.
- **Localized**: every user-facing string in English and French (the app's ARB files).
- **Showable**: each session ends with the app runnable and a screenshot or recording in its session log.

---

## Issue 1: Normal launch, from the playtest
Rules: decisions 3, 5, 236; Q-MAP-22; stack decisions 4, 7.
Package: `battle_team`.
Depends on: the playtest (merged).

- The playtest feature (`lib/playtest/`) becomes the app's battle feature, layered (a repository over `battle_client`, a bloc, the 3D view behind the rendering seams of the conventions). The `development`, `staging` and `production` flavors open into the battle of their configuration after sign-in; until Issue 12, sign-in stays the `env/` file of the playtest. The playtest flavor remains a thin entry over the same feature.
- The **Flame scaffold leaves the app** (stack decision 4, designer 2026-11-09): the Flame dependency, `lib/game/` and the scaffold screens tied to it.
- The map's attribution is shown where the map is (Q-MAP-22): the battle screen's credits entry, from `map.yaml`.

Acceptance criteria:
- The development flavor signs in and plays the playtest battle as the playtest flavor did; Flame is out of `pubspec.yaml`.
- The battle feature is layered and its bloc tested without a socket (recorded streams, as battle_client's tests).
- A screenshot in the session log.

## Issue 2: The test unit and the AP recovery delay
Rules: decisions 238, 239; COMBAT-02, UNIT-44; Q-UNIT-26.
Packages: `battle_rules`, `battle_host`, `battle_team` (`plan/data`).
Depends on: nothing (runs beside Issue 1).

- `battle_rules` and `battle_host` read AP recovery as `ap.recovery_delay_s` (the delay to gain one AP), from the battle's settings when they override the default (decision 238). `data/battle.yaml` already holds the new key.
- The test unit in `data/units.yaml` (UNIT-44, Q-UNIT-26's assumptions), allowed only where the battle setting `test_units` is on; the host refuses buying it elsewhere.
- `battle_host tool/playtest.dart` creates testing battles: `test_units` on, a short recovery delay, and blue's opening buys a test unit.

Acceptance criteria:
- A battle with a 1 s recovery delay moves a soldier continuously; the default battle is unchanged (3600 s).
- Buying a test unit in a battle without `test_units` is refused; with it, the unit holds 10,000 AP and every action.
- The playtest battle plays with a test unit and a short delay; every later issue tests against it.

## Issue 3: Logging
Rules: decision 237 (logs show nothing hidden); stack decision 7.
Packages: `battle_team`, `battle_client`, hawkbee `packages/appwrite_api_client`.
Depends on: 1.

- One small logging setup on `package:logging`: per-class loggers, one formatter, readable in logcat and the console, quiet in release. It replaces the TEMP prints the phone playtest needed (reverted with hawkbee1/hawkbee#69).
- `battle_client` logs its connection lifecycle (attempts, credential kind, host address, socket end reasons, refusals) behind its port; the app logs bloc errors and order refusals.
- The format is what the hawkbee `watch-debug-session` skill reads: stable prefixes, one line per event, errors marked.

Acceptance criteria:
- A playtest run on a phone shows sign-in, host lookup, socket and order lifecycles in logcat; a forced failure (host down) is found from the logs alone.
- Nothing a section does not see appears in any log line (decision 237).

## Issue 4: View from a unit
Rules: decision 5; MAP-04; COMBAT-14 (the basis; aimed fire is Issue 5); stack decisions 3 (move stream rate), 4.
Package: `battle_team`.
Depends on: 3.

- First-person control of one selected unit through its eyes: enter from the unit, leave back to top-down. The camera seam of the conventions carries both modes.
- Movement in first person uses the move stream rate of `stack/03`; the AP shown between updates comes from `battle_client` (clock sync, stack decision 8).
- What the unit's section does not see is not drawn, in either mode.

Acceptance criteria:
- Top-down and first person switch on the playtest battle on a phone; a recording in the session log.
- The first-person rate and its traffic are recorded next to `stack/03`'s estimate.

## Issue 5: Fire
Rules: COMBAT-11 to COMBAT-26 (seeing, hitting, damage, weapons), COMBAT-57, COMBAT-58; decisions 183, 234, 237; UNIT-38 (refused actions).
Packages: `battle_team`, `battle_client` (pre-check).
Depends on: 4.

- The orders `Fire`, `FireAtPosition`, `FireAimed` (first person, Issue 4), `Reload`, `SwapWeapon`; the weapon, its ammunition and reload state shown on the selected unit.
- Shots and bursts drawn from the stream's events; hits shown, including a hit on a seen unit by an unseen shooter, with nothing of the shooter (decisions 234, 237).
- Refusals (AP, range, ammunition, an action the unit cannot do) surfaced where the order was given.

Acceptance criteria:
- A test unit fires each way at the stored streams and on the playtest battle; hits and unseen hits drawn as decisions 234/237 demand, proven over a scripted battle.
- A recording in the session log.

## Issue 6: Storage: view, store, unstore
Rules: HQ-29, HQ-31 to HQ-36, HQ-39, HQ-46; decisions 110, 120, 125, 204.
Package: `battle_team`.
Depends on: 1 (and 2 for fast testing).

- A storage view: the stored units, the portal, the deploy cost, the 24-hour lock and its remaining time, the blocked-by-enemy state; prisoners listed.
- `Store` (with the recall delay from afar), `Recall`, and `Deploy` from the view (the playtest's Deploy moves here).

Acceptance criteria:
- Store, recall and deploy from the view on the playtest battle; a blocked deployment (enemy within 20 m) and the lock shown with their reasons.
- A screenshot in the session log.

## Issue 7: Buy
Rules: ECO-04 to ECO-07, HQ-42, HQ-46; COMBAT-27; decisions 129, 130, 147, 205, 210.
Package: `battle_team`.
Depends on: 6.

- The section's money shown; `BuyUnit` from the roster with prices, `BuyWeapon` for a unit. The guild camp (`BuyGuildCamp`) and the skill tree (`BuyNode`) wait for a later progression session.
- Refusals (money, room, lock, enemy at the portal) surfaced.

Acceptance criteria:
- Buying a unit and a weapon on the playtest battle, prices from `data/`; each refusal shown with its reason.
- A screenshot in the session log.

## Issue 8: Move: path preview and AP cost
Rules: COMBAT-03, COMBAT-06; `specs/10-map-and-terrain.md` sections 3 (movement) and 4 (water); decision 236; stack decision 8.
Packages: `battle_client` (pre-check), `battle_team`.
Depends on: 1 (and 2 for fast testing).

- The order pre-check of stack decision 8, in `battle_client` (as M6.7 planned): before sending a move, the path and its AP cost from `battle_rules` on the client's map data, for display only.
- The preview drawn before confirming; the moving unit keeps gliding to its arrival (decision 236); the cost against the unit's AP, and the wait COMBAT-06 implies when AP run short.
- The host's answer wins: a divergence is shown, not argued.

Acceptance criteria:
- The preview's path and cost equal the host's refusal boundary on scripted cases (grass, slope, road, water).
- A recording in the session log.

## Issue 9: Fog shading and alerts
Rules: MAP-27, MAP-29, MAP-33, MAP-49; RELIC-10, RELIC-16; decisions 232, 233, 235, 237.
Package: `battle_team`.
Depends on: 4.

- The ground shaded by what the section sees now; what it has never seen against what it saw once may differ; units out of sight disappear (they already do).
- Alerts surfaced: the relic alert (also on connect, decision 233) and the victory countdown (RELIC-16), with what MAP-49 makes known to all.

Acceptance criteria:
- The shading matches the section's visible set over a scripted battle; no clue about the unseen (decision 237).
- A recording with two sections seeing differently, in the session log.

## Issue 10: Pings, map markers and team chat
Rules: SOC-34, SOC-36, SOC-37; decision 123; stack decision 3 (sizes).
Packages: `battle_protocol`, `battle_host`, `battle_client`, `battle_team`.
Depends on: 1.

- New messages (M6's conventions: samples, both encodings, sizes against `stack/03`): a ping and a map marker to the team, team chat with history (SOC-36). Nothing crosses teams (SOC-34).
- The Discord sync of team chat (SOC-37) waits for the bridge (`battle_discord_bridge`, stack decision 7): the message design must not block it.
- In the app: ping and marker placed on the map, chat as a panel over the battle.

Acceptance criteria:
- Two clients of one team exchange pings, markers and chat on the loopback interface; a third, enemy client receives nothing of them.
- Encoded sizes recorded next to `stack/03`; a recording in the session log.

## Issue 11: Unit filters
Rules: Q-MAP-27 (a seen unit shows its team); decision 21.
Package: `battle_team`.
Depends on: 1.

- Filters over what is drawn and listed: my units, friendly units, enemy units, my guild's units. A filter hides; it never reveals (decision 237). The guild of a friendly section, if the view lacks it, extends the protocol under M6's conventions.

Acceptance criteria:
- Each filter on the playtest battle with two sections; a screenshot per filter in the session log.

## Issue 12: Accounts: sign up, sign in, log out
Rules: decisions 126 (later), 220; stack decision 6.
Package: `battle_team`, hawkbee `packages/appwrite_api_client`.
Depends on: 1.

- Sign up, sign in and log out on Appwrite (email and password), the session kept across restarts; the battle entered from the account's section (`EnterBattle` is the host's, decision 220). The `env/` sign-in of Issue 1 remains for the playtest flavor only.
- The newcomer flow (guild choice, SOC-03) and Discord linking (decision 126) wait for their own sessions.

Acceptance criteria:
- A new account signs up, enters the battle its section is in, logs out and back in on a phone; wrong passwords and an unreachable Appwrite surfaced.
- A recording in the session log.

## Issue 13: P-05 and P-06, the rendering benchmarks
Rules: none new; P-05, P-06; stack decisions 4, 5.
Package: `battle_team` (and `linux/` platform folder, stack decision 4).
Depends on: 9 (fog and units drawn as they will be).

- P-05: 1,000 units on screen in profile mode, UI and raster threads apart, on the designer's devices (`stack/04`); the slowest becomes the reference. P-06: tile loading, first frame, tile memory, a crater applied.
- The `linux/` platform folder is added (stack decision 4).
- Results to `stack/04` and `stack/05`; the fixes, in the order of the flutter_scene performance method, are planned as follow-up sessions from the measurements, through the seams the conventions kept.

Acceptance criteria:
- P-05 and P-06 committed in `performance-tests.md` with the reference device named; `stack/04`'s risk paragraph replaced by measurements.

---

Parallel: Issue 2 (packages only) runs beside Issue 1; 3 after 1; 4, 6, 8, 10, 11 and 12 after their dependencies in the order above; 5 after 4; 7 after 6; 9 after 4; 13 after 9, on the designer's devices. M6 Issue 8 (the network load test, P-04) is still open and independent. Two sessions of one package rebase on `main` before opening their PR.
