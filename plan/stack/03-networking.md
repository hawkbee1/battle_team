# Stack decision 3: networking

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 3). Rules: decisions 2, 3, 4, 5; MAP-08, MAP-29; RELIC-10 (alerts); decisions 161, 165, 166, 172, 183; AI-03, AI-09.

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
5. **dashwire, through `flutter_scene_net`**. A multiplayer library that already does replication and interpolation, and binds replicas to scene nodes. Its host runs inside the app and is native only (a stub on the web), so the dedicated Dart host of `01-simulation-host.md` would use dashwire's protocol, not its host. **Not evaluated yet.** It is a candidate for the M6 spike, against option 3.

## Choice
**Option 3.** Orders are the same typed commands whatever their sender. A player sends them over the WebSocket; an AI agent or the server sends them over HTTPS with its key (AI-04). The host checks the sender, applies the same rules, and logs the origin (stack decision 2).

Update policy:
- A unit that moves is sent at **5 Hz** while it moves. A unit that stands still sends nothing.
- Events (a shot, a hit, a death, a capture progress change, a move order) are sent when they happen.
- Things that do not change are not sent. Each client keeps the last state it received.
- Client-side interpolation between updates hides the 200 ms cadence.

Fog filter: the host computes each section's visible set once per tick (see stack decision 1) and sends each section only what it sees.

What orders carry: a shot carries its aim direction and fire time (decision 183); a move order may carry the client's path, which the host checks (stack decision 8). First-person movement is a stream of short move orders, about 5 to 10 a second while the player holds a direction. It is small and bounded by AP (an infantry pool is a 30 m dash); the rate is set with the protocol (M6).

## Traffic estimate for one section during a fight
Re-estimated 2026-11-01 from the AP rules (stack decision 1). Assumptions: a section has at most 16 units, so it holds 480 AP at battle start (16 × 30). A viewer sees up to 10 sections fighting at once. An event is about 40 bytes. A moving unit streams its position at 16 bytes × 5 Hz.
- **Events:** at the typical mix, 480 AP is about 80 events over 10 minutes (0.13 per second per section). At worst, with 1 m orders, it is 480 events (0.8 per second). Ten fighting sections give 1.3 to 8 events per second, about **0.4 to 2.6 kbit/s down**.
- **Moving units:** only while they move. Ten vehicles moving in view at once: 10 × 16 bytes × 5 Hz = 800 bytes per second, about **6 kbit/s down**. Infantry at its default pace streams nothing.
- **Orders upstream:** one per event, about 40 bytes, at most 0.8 a second: under **0.3 kbit/s up**.
- Total: about **7 to 9 kbit/s down and under 0.5 kbit/s up** during a fight. Between fights, close to zero.
- **Peak:** rested units spend their pools in seconds (stack decision 1). If ten sections (160 units) open fire together, one event per shot gives about 110 events per second with rifles (**about 35 kbit/s down for about 20 s**) and about 1,300 with machine guns (**about 430 kbit/s for about 4 s**). Grouping each unit's shots into one event per tick (shots, hits, damage) caps it at 160 events per second, about 51 kbit/s.

Late join: the visible state plus the delta layer. The delta layer is a list of changed objects (built structures, destroyed objects, craters), a few tens of thousands of entries at most, about 16 bytes each: a few hundred kilobytes, compressed. Terrain changes do not depend on AP. The estimate is to be checked against a real battle (M8).

## Consequences
- The host needs a WebSocket endpoint for players and an HTTPS endpoint for AI agents and the server. Both feed the same command handler.
- Players sign in with a short-lived Appwrite JWT (`account.createJWT`, valid 15 minutes) sent when the socket opens. The host checks it once with Appwrite (local in development, Appwrite Cloud live) and binds the socket to the account; orders never touch Appwrite. AI calls are checked with the account's API key (decision 158). The two checks produce the origin tag used in the log (decision 162).
- The protocol (message formats, versions) becomes a contract between `battle_host` and the client. It is written down in M5 or M6, in the same package as the rules core.
- The number of moving vehicles in view and the shape of fire bursts are now the main traffic levers, since infantry rarely moves. Grouping shots per unit per tick is decided with the protocol (M5 or M6). The 5 Hz cadence and fog per section are still tuned with the scenario harness (M4 Issue 11), not by guessing.
