# Milestone 6: networking

Goal: players and AI agents play a battle of M5 over the network. Players send orders over a WebSocket, and AI agents send them over the same WebSocket or over HTTPS. All of them go through the one command handler of M5. Each section receives only what it sees, as a stream of updates, and a late joiner or a returning player catches up from one message. No rendering: the client of M7 builds on the client library of this milestone. Stack from M2: `stack/03` (networking), `stack/06` (sign-in, API keys), `stack/08` (what runs where, client trust), `stack/01` (hosting, placement), `stack/07` (principles, packages).

Each issue below is one agent work session (hawkbee `docs/battle_team/`).

## Packages
| Package | What it gains | Created in |
|---|---|---|
| `battle_protocol` | The messages between the host and its clients, beside the commands and events of M5. | M5 |
| `battle_host` | Fog of war per section, the update stream, the WebSocket and HTTPS endpoints, sign-in. | M5 |
| `battle_client` | The client side of a connection: sign-in, sending orders, the section's view kept up to date, reconnection. Shared by the app (M7) and AI agents written in Dart. | Issue 7 |
| hawkbee `backend/`, `hawkbee_schema` | Where a client finds the host of its battle. | M5 |

## Conventions
- Those of M5 (`milestones/m5-simulation-host.md`, "Conventions"): one repository per package, 100 % line coverage, numbers only in `plan/data`, deterministic, immutable models, rule IDs in test names, ports and adapters, contract suites, Appwrite tests tagged and opt-in.
- **Network I/O in adapters.** Sockets and HTTP live in adapters behind ports. The fog filter, the update stream and the sign-in logic are tested without a socket. Socket tests run on the loopback interface only.
- **Nothing hidden leaves the host** (MAP-29, stack decisions 3 and 8). No message to a section names a unit, a position or an event its section does not see, except what the rules make known to all. Each issue that adds a message proves this with a test over a scripted battle.
- **A client is never trusted** (stack decision 8). The host checks every order as in M5, whatever the client says it checked.
- **Sizes against the estimates.** Each issue that adds a message reports its encoded size next to the estimate of `stack/03`.
- **Replay unchanged.** What a section sees is computed from the battle state; it is never logged. A recovered host sends the same view as a host that never stopped.

---

## Issue 1: Protocol spike, dashwire against M5's protocol
Rules: none; stack decision 3 (option 5 against option 3).
Package: none merged. The spike's code stays on its branch; its result goes to `stack/03`.

- `stack/03` left dashwire (`dashwire`, `dashwire_replication`, used by `flutter_scene_net`) unevaluated, as a candidate against option 3, which M5.9 already began with `battle_protocol`.
- Check, on its current release: does its server library run in a pure Dart AOT executable such as `battle_host`; can its relevancy filter carry per-section fog (MAP-29) computed by the host; does its client run on the web; what a 5 Hz position update and an event cost in bytes against `battle_protocol`'s binary encoding; its licence (`packages_check_licenses`); and what adopting it would change in `battle_host` and in `battle_protocol`'s frozen version 1.
- The same small scripted fight encoded both ways.

Acceptance criteria:
- A comparison in `stack/03`, option 5, with the measured sizes and a recommendation. The designer confirms the choice. Until then the next issues follow option 3, the confirmed choice.

## Issue 2: Messages between the host and its clients
Rules: MAP-08, MAP-29, MAP-49, RELIC-10, RELIC-16, COMBAT-57, AI-03, AI-05; decisions 21, 162, 183, 232 to 234; stack decision 3.
Package: `battle_protocol`.
Depends on: 1.

- **From a client:** sign-in (the protocol version, the battle, and an Appwrite JWT or an API key), a command with a request ID chosen by the client, a resync request, a heartbeat.
- **From the host:** sign-in accepted (the account, its section in the battle, the battle time) or refused; a command accepted (its request ID and sequence number) or refused (its request ID and the refusal code of M5.11); the whole view of a section (Issue 4); the update of one tick; an alert (RELIC-10); goodbye with a reason (the battle ended, a revoked key, a protocol version the host does not speak).
- **The view of a section:** the units it sees, each with its state at its last update and its rates (stack decision 8: the client computes AP between updates); its own private state (AP, morale, money, XP, stored units, prisoners, offers, locks); the relics, the HQs it sees, and the victory countdown (RELIC-16); the delta layer (MAP-08).
- **The update of a tick:** the positions of moving units it sees (5 Hz, quantised), units that came into sight (whole) or went out of it (ID only), the events it may see, and its private state that changed.
- The update policy of `stack/03`: grouping a unit's shots of one tick into one message, and the rate of the first-person move stream, are set here and recorded in `stack/03`.
- Both encodings of M5.9; committed samples freeze the messages as M5.9 froze the commands and events.

Acceptance criteria:
- Every message round-trips through both encodings; the committed samples fail the tests on a breaking change.
- Encoded sizes of a moving unit's position, an event, a tick with ten moving vehicles and the view of a 16-unit section, next to `stack/03`'s estimates.

## Issue 3: Fog of war per section
Rules: MAP-27, MAP-29, MAP-33, MAP-49, UNIT-34, UNIT-36, HQ-29, COMBAT-11, COMBAT-12; decisions 21, 59, 184, 232.
Package: `battle_host`.
Depends on: M5 (not on Issue 1).

- Once per tick, each section's visible set: what its own units see (the vision rules of M4.5 with effective stats: range, weather, forest, height, observe), and the enemies its team's scouts spot, relayed by a radio in range to every section of the team (UNIT-34, UNIT-36). Stored units are seen by nobody but their section (HQ-29).
- What every section knows whatever it sees (MAP-49).
- The scouts' reports artillery may fire at (COMBAT-12, M5.11) and this relay are one computation.
- The cost: only what moved, appeared or changed sight since the last tick is checked again. The cost per tick of a 1,000-unit battle is measured with M5.19's load test.

Acceptance criteria:
- A unit behind a forest, behind a hill, out of range and in fog is not seen; observing widens the set; a radio relays a scout's report to an allied section in its range and not to one out of it; a stored unit leaves every set but its own section's; a unit of an allied section is seen only when one of the section's units sees it (decision 21).
- A recovered host gives the same visible sets as a host that never stopped.
- The cost per tick at 1,000 units, peak and average, added to P-02.

## Issue 4: The update stream of a section
Rules: MAP-08, MAP-29, MAP-49, RELIC-10, RELIC-16, HQ-29, COMBAT-57; decisions 21, 100, 232 to 234; stack decision 3 (update policy).
Package: `battle_host`.
Depends on: 2, 3.

- Each section has a subscriber (Observer): after each tick and each accepted order, the host builds the section's update from the battle's events and the change of its visible set, with the policy of `stack/03` (a moving unit at 5 Hz, a still unit nothing, events when they happen, nothing unchanged).
- An event about something the section does not see is cut down to what it sees, or not sent (COMBAT-57).
- Private state goes to its own section only.
- The alert of RELIC-10 goes to the previous owner team: at once to its connected players, and to each of the others when they next connect (decision 233). The victory countdown goes to every section.
- A section that subscribes late, or again, gets its whole view first, the delta layer included (MAP-08), then the updates.

Acceptance criteria:
- On the scripted battle of M5.15, a subscriber that joins halfway holds the same view at the end as one present from the start.
- Over the same battle, no update to a section names a unit outside its visible set at that time, except its own units and what MAP-49 makes known to all.
- A relic captured alerts the previous owner team and nobody else; a player of that team who connects afterwards receives the alert once.

## Issue 5: Endpoints and sign-in
Rules: AI-02, AI-03, AI-04, AI-05, HQ-07; decisions 157, 158, 161, 162, 220; stack decisions 3, 6.
Package: `battle_host`.
Depends on: 2, 4.

- A WebSocket endpoint for players and AI agents, and an HTTPS endpoint for single orders in JSON, both feeding `SimulationHost.submit`.
- Sign-in on the socket: an Appwrite JWT, checked once with Appwrite, binds the socket to the account and to its section in the battle; or an API key, which the host resolves to its account by its hash (stack decision 6). The check goes through a port, with a fake and an Appwrite adapter that pass one contract suite. A player's sign-in is the server's `EnterBattle` command (HQ-07, decision 220).
- On HTTPS, each call carries the API key as a bearer token and is checked again, so a revoked key is refused on the next call (decision 161). Origin: `player` for a JWT, `ai` for a key (decision 162).
- The sender of a command is the signed-in account and its section, whatever the client wrote.
- A command is acknowledged only once its entry is on disk (M5.15). A command resent with a request ID the host already answered gets the first answer again and is not carried out twice.
- The rate limit, one per sender, the same for players and AI agents (AI-03), set for real play: a section's machine guns firing together are not throttled (P-02); a flood is.
- Heartbeats and an idle timeout. A slow client's queue is bounded; past the bound the host drops it, and it catches up with its whole view when it comes back.
- A socket that closes changes nothing in the battle: the section's units stay passive (AI-02).

Acceptance criteria:
- A sign-in with a fake JWT and with a key; refused: a bad JWT, a battle the account has no section in, an unknown protocol version, a key revoked between two calls, a command for another section.
- An order over the socket logged with the origin `player`, one over HTTPS with `ai`.
- A resent command carried out once; a flood throttled while a section's machine-gun burst is not.
- Sign-in with a JWT of the local Appwrite, by an opt-in test.

## Issue 6: Reaching a battle's host
Rules: none new; stack decisions 1 (placement), 3, 6.
Packages: `battle_host` (`docker/`), hawkbee `backend/`, `hawkbee_schema`.
Depends on: 5.

- A client knows only the battle. It finds the address of the host that runs it from Appwrite: the placement of M5.19 (`battles.host`) gains each host's public address. Players read only what their battles need.
- TLS: live, `wss` and `https` end at a reverse proxy in front of the containers; locally, the containers are reached as the local Appwrite is (`docs/project-setup.md`).
- A battle that moves to another host after a restart: the client finds the new address and signs in again.
- The resources still to push from M5.15 and M5.19 (the `host` column, the buckets) are pushed with this issue's.

Acceptance criteria:
- On the local stack, a client given only a battle ID opens a socket to its host and signs in.
- A host restarted on another container: the client reaches the battle again.

## Issue 7: Client library
Rules: MAP-08; stack decisions 3, 8.
Package: `battle_client` (new, `dart_package`).
Depends on: 2, 4.

- A pure Dart library that runs in the app (M7) on every target, the web included, and in AI agents written in Dart. Its transport is an adapter behind a port, so tests feed it recorded streams.
- Sign-in with a JWT or an API key; sending a command and getting its answer by its request ID.
- The section's view, kept from its whole view and its updates; the AP shown between updates computed from the last value and the rate (stack decision 8). Interpolation and drawing are M7's.
- Reconnection with backoff: the client signs in again, takes its whole view, and resends the commands that got no answer with their request IDs (Issue 5 carries each out once).
- An example AI agent in `bin/`: it signs in with an API key and fires at the nearest enemy each of its units sees.

Acceptance criteria:
- A view fed a recorded stream equals the host's view of that section.
- A socket dropped with a command in flight: after reconnection the command is carried out once and the view is whole.
- The library compiles to JavaScript.

## Issue 8: A battle over the network, P-04
Rules: none new; P-04; stack decisions 1, 3.
Packages: `battle_host`, `battle_client`.
Depends on: 5, 7.

- M5.19's load test played over sockets on the loopback interface: each section a `battle_client`, 100 players and some AI agents over HTTPS, on `saint_lo`.
- P-04: bytes per second to one section in a fight, at its bursts (rifles, machine guns), up and down; the size of a whole view at a late join; the host's CPU for the fan-out, per battle and for ten battles in one process (`stack/01`).
- The 5 Hz cadence and the grouping of shots are tuned with the measurement (`stack/03`).

Acceptance criteria:
- P-04 committed in `performance-tests.md`; `stack/03`'s traffic estimate replaced by the measurement.
- A battle played over the network to its end: every client receives its end.

---

Parallel: Issue 3 starts with Issue 1; 2 after 1; 4 after 2 and 3; 5 and 7 after 4; 6 after 5; 8 after 5 and 7. Two sessions of one package rebase on `main` before opening their PR.
