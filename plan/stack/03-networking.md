# Stack decision 3: networking

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 3), and again after the comparison with dashwire (designer, 2026-11-08; milestone M6, Issue 1). Rules: decisions 2, 3, 4, 5; MAP-08, MAP-29; RELIC-10 (alerts); decisions 161, 165, 166, 172, 183; AI-03, AI-09.

## What the rules require
- Orders reach the server and state reaches the players in **real time**, for 100+ players per battle (decisions 2 and 4).
- **Fog of war per section**, filtered on the server (MAP-29). A client never receives what its section cannot see.
- **Alerts** (RELIC-10), and **late joiners** receive the delta layer (MAP-08).
- Three kinds of sender use the same order interface: players (top-down and first-person control, decision 5), AI agents (AI-03), and the server for its own sections (AI-09, decision 165).

## Options
1. **Appwrite Realtime** (channels on database changes). Built for documents, not for positions updated several times a second. Each unit change would become a database write, which is the cost decision 2 avoids. Rejected for game state. Possible for slow notifications such as a war announcement.
2. **WebSocket with JSON messages.** Simple, works on iOS, Android, Web and Windows. JSON is large for positions, and parsing costs CPU on the client.
3. **WebSocket with binary messages** for state (compact encoding with quantised positions, sent as deltas), and the same interface for orders. For AI agents and the server, the same order is also accepted over HTTPS with a JSON body, because they send single requests and do not need a socket.
4. **UDP or WebRTC**. Not available uniformly in Flutter on the Web, and too much for this scale. Rejected.
5. **dashwire, through `flutter_scene_net`**. A multiplayer library that already does replication and interpolation, and binds replicas to scene nodes. `flutter_scene_net`'s host runs inside the app and is native only, so the dedicated Dart host of `01-simulation-host.md` would run dashwire's own server library. Compared with option 3 in M6 Issue 1, below.

### Option 5 against option 3 (M6 Issue 1, 2026-11-08)
Checked on the code of `dashwire` 0.1.0 and `dashwire_replication` 0.2.1, the current releases:
- **Pure Dart AOT host: yes.** The server pieces use `dart:io` (a WebSocket server) and `dart:isolate` (one room per isolate), no Flutter. A `dart compile exe` executable ran a room in an isolate behind a loopback WebSocket, refused a bad token and replicated a moving unit.
- **Fog per section: for state, yes.** The host hands `ReplicationHost` a relevancy filter that returns, per connection, the IDs it sees: the host's own visible set fits. A field reaches everyone, its owner's connection only, or all but its owner. Events do not fit: an RPC reaches every connection that knows its replica, unchanged. An event cut down to what a section sees (COMBAT-57), an alert to one team (RELIC-10) and the delta layer (MAP-08) would be the app's own messages.
- **Web client: yes.** The client compiles to JavaScript and to Wasm, runs under both, and uses the browser's WebSocket through `package:web`; the schema hash is the same on the VM, in JavaScript and in Wasm. Over a WebSocket its unreliable channel is reliable.
- **Option 3 on the web:** `battle_protocol` compiled to JavaScript and to Wasm decodes and re-encodes every committed sample of version 1 to the same bytes and JSON, as on the VM, integers up to 2^52 − 1 included. Its client socket (M6 Issue 7) uses `package:web`, not `dart:html`, which Wasm lacks.
- **Licence:** MIT for both; their dependencies `web` and `meta` are BSD-3.
- **Maturity:** versions 0.x, one author, first release July 2026; 0.2.0 broke the API.

The same scripted fight, seen by one section, encoded both ways. Binary, in bytes, without the WebSocket frame header; IDs of 6 to 14 characters as in M5.9's samples; option 3's position update is a stand-in until M6 Issue 2 defines it.

| Message | Option 3 | dashwire |
|---|---|---|
| The position of one moving unit, one tick | 22 | 25 |
| A tick with ten moving vehicles | 167 | 205 |
| A rifle shot, one impact | 53 | 43 |
| A machine-gun burst grouped, three impacts | 112 | 99 |
| The whole view of 16 units | 649 | 784 |
| A 2-second fight: a tank moving, four shots, a death | 469 | 431 |

dashwire adds a clock-sync ping four times a second (10 bytes up, 21 down: about 0.3 kbit/s up and 0.7 down, adjustable) and a 4-byte acknowledgement per state update. Its positions cost 3 to 4 bytes more per unit (a version, a length and a 32-bit field mask); its events about 10 bytes less, because it names objects with numbers. A battle-wide ID table, which M5.9 named as a version 2 change, gives option 3 the same saving. Neither wins on size.

What adopting dashwire would change:
- **`battle_host`:** a replica for each unit, HQ and relic, mirroring the battle state and updated from the events after each tick, with a table from the battle's IDs to dashwire's that recovery rebuilds identically. Its token check answers only yes or no, so binding a socket to an account and its section needs a wrapper; a connection's number changes when it reconnects, so a section's replicas change owner. Commands do not fit its RPCs (no request ID, no answer, nothing waits for the write-ahead log, orders that act on no unit), so they stay `battle_protocol` commands in its raw messages. HTTPS for AI agents, the rate limit, alerts, the delta layer and the victory countdown are not in dashwire.
- **`battle_protocol` version 1:** unchanged (commands, events, log). M6 Issue 2's view and tick update would become replica schemas, and a client would hold two kinds of ID: numbers for state, strings in events.
- **What it brings:** a byte budget per connection that sends the longest-waiting changes first, so a burst spreads over a few ticks; clock sync; and, in M7, `flutter_scene_net`'s interpolation buffer and binding of replicas to scene nodes.

**Choice: option 3, confirmed** (designer, 2026-11-08). dashwire would carry only the replication of state: sign-in, orders, events, alerts and the delta layer stay this project's code either way, the sizes are even, and the library is young. Worth reusing in option 3: a byte budget per section that sends the moving units waiting longest first (M6 Issue 4), and clock sync for the AP shown between updates (M6 Issue 7). `flutter_scene_net`'s interpolation buffer is a model for M7.

## Choice
**Option 3.** Orders are the same typed commands whatever their sender. A player sends them over the WebSocket; an AI agent or the server sends them over HTTPS with its key (AI-04). The host checks the sender, applies the same rules, and logs the origin (stack decision 2).

Update policy (messages in `battle_protocol`, M6 Issue 2):
- A unit that moves is sent as its **position only**, quantised to the centimetre, when it changes. The host places a moving unit at its destination as its move starts (decision 236), so it is sent once per move; the client animates it there by its move's arrival time. Following units along their paths, at **5 Hz**, is planned for later (M8). Not a path nor a speed: a path would show a section where an enemy goes beyond what it sees (MAP-29), and its own units' paths are the ones it sent.
- A unit that stands still sends nothing.
- Events (a shot, a hit, a death, a capture progress change, a move order) are sent when they happen, in the update of their tick.
- **A unit's shots of one tick are grouped into one burst**: its weapon, the shots fired and those that hit, and each unit hit once with the damage of all of them. The battle log keeps every shot.
- A hit by a shooter the section does not see comes as the unit hit and its damage only (COMBAT-57). A shot of a unit it sees whose target or outcome it does not see comes as that unit firing, with only the hits it sees (COMBAT-58).
- Things that do not change are not sent. Each client keeps the last state it received; it asks for its whole view again when it lost track.
- Client-side interpolation between updates hides the 200 ms cadence.

Fog filter: the host computes each section's visible set once per tick (see stack decision 1) and sends each section only what it sees.

What orders carry: a shot carries its aim direction and fire time (decision 183); a move order may carry the client's path, which the host checks (stack decision 8). First-person movement is a stream of short move orders, **5 a second** while the player holds a direction, the cadence of the position updates; the client moves its unit between them. It is small and bounded by AP (an infantry pool is a 30 m dash).

## Traffic estimate for one section during a fight
Re-estimated 2026-11-01 from the AP rules (stack decision 1). Assumptions: a section has at most 16 units, so it holds 480 AP at battle start (16 × 30). A viewer sees up to 10 sections fighting at once. An event is about 40 bytes. A moving unit streams its position at 16 bytes × 5 Hz.
- **Events:** at the typical mix, 480 AP is about 80 events over 10 minutes (0.13 per second per section). At worst, with 1 m orders, it is 480 events (0.8 per second). Ten fighting sections give 1.3 to 8 events per second, about **0.4 to 2.6 kbit/s down**.
- **Moving units:** only while they move. Ten vehicles moving in view at once: 10 × 16 bytes × 5 Hz = 800 bytes per second, about **6 kbit/s down**. Infantry at its default pace streams nothing.
- **Orders upstream:** one per event, about 40 bytes, at most 0.8 a second: under **0.3 kbit/s up**.
- Total: about **7 to 9 kbit/s down and under 0.5 kbit/s up** during a fight. Between fights, close to zero.
- **Peak:** rested units spend their pools in seconds (stack decision 1). If ten sections (160 units) open fire together, one event per shot gives about 110 events per second with rifles (**about 35 kbit/s down for about 20 s**) and about 1,300 with machine guns (**about 430 kbit/s for about 4 s**). Grouping each unit's shots into one event per tick (shots, hits, damage) caps it at 160 events per second, about 51 kbit/s.

Measured (M6 Issue 2, `battle_protocol`'s committed samples, binary, without the WebSocket frame header; IDs of 6 to 14 characters):

| Message | Measured | Estimate |
|---|---|---|
| A tick update with nothing but its time | 20 bytes | |
| One moving unit in a tick | 18 bytes more | 16 bytes |
| A tick with ten moving vehicles | 200 bytes | 160 bytes |
| A rifle shot (one hit) as an event | 55 bytes; 73 as a whole tick | 40 bytes |
| A hit by a shooter not seen, as a whole tick | 39 bytes | |
| The whole view of a 16-unit section, its private state and 8 relics | 2,239 bytes (5,833 in JSON) | |

Ten moving vehicles at 5 Hz, once units follow their paths, are about 1 kB a second, **8 kbit/s** instead of 6; events are about a third larger than assumed. The fight totals stay under **12 kbit/s down**. The string IDs dominate, as in the log: a battle-wide ID table remains the version 2 saving.

Late join: the visible state plus the delta layer. The delta layer is a list of changed objects (built structures, destroyed objects, craters), a few tens of thousands of entries at most, about 16 bytes each: a few hundred kilobytes, compressed. Terrain changes do not depend on AP. The estimate is to be checked against a real battle (M8).

## Consequences
- The host needs a WebSocket endpoint for players and an HTTPS endpoint for AI agents and the server. Both feed the same command handler.
- Players sign in with a short-lived Appwrite JWT (`account.createJWT`, valid 15 minutes) sent when the socket opens. The host checks it once with Appwrite (local in development, Appwrite Cloud live) and binds the socket to the account; orders never touch Appwrite. AI calls are checked with the account's API key (decision 158). The two checks produce the origin tag used in the log (decision 162).
- The protocol (message formats, versions) becomes a contract between `battle_host` and the client. It is written down in M5 or M6, in the same package as the rules core.
- The number of moving vehicles in view and the shape of fire bursts are now the main traffic levers, since infantry rarely moves. Shots are grouped per unit per tick (M6 Issue 2). The 5 Hz cadence (once units follow their paths) and fog per section are still tuned with the scenario harness (M4 Issue 11), not by guessing.
