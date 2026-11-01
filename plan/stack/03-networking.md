# Stack decision 3: networking

Status: **proposed** (milestone M2, Issue 3). Rules: decisions 2, 3, 4, 5; MAP-08, MAP-29; RELIC-10 (alerts); decisions 161, 165, 166; AI-03, AI-09.

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
**Option 3.** Orders are the same typed commands whatever their sender. A player sends them over the WebSocket; an AI agent or the server sends them over HTTPS with its key (AI-04). The host checks the sender, applies the same rules, and logs the origin (decision 2).

Update policy:
- Moving units in a section's view are sent at **5 Hz**.
- Events (a shot, a hit, a death, a capture progress change) are sent when they happen.
- Things that do not change are not sent. Each client keeps the last state it received.
- Client-side interpolation between updates hides the 200 ms cadence.

Fog filter: the host computes each section's visible set once per tick (see decision 1) and sends each section only what it sees.

## Traffic estimate for one section during a fight
Assumptions: a section has at most 16 units (decision 144 at level 60). At peak, its view holds about 100 units (own and enemy). Quantised positions and state are about 16 bytes per unit.
- Position updates: 100 units × 16 bytes × 5 Hz = **8 KB/s, about 64 kbit/s** downstream.
- Events: about 20 per second × 40 bytes = 0.8 KB/s.
- Orders upstream: a few hundred bytes per second at most.
- Total: about **70 kbit/s down and under 5 kbit/s up** during a fight. Between fights, close to zero.

Late join: the visible state plus the delta layer. The delta layer is a list of changed objects (built structures, destroyed objects, craters), a few tens of thousands of entries at most, about 16 bytes each: a few hundred kilobytes, compressed. The estimate is to be checked against a real battle (M8).

## Consequences
- The host needs a WebSocket endpoint for players and an HTTPS endpoint for AI agents and the server. Both feed the same command handler.
- Player accounts are checked with the Appwrite session token on connection. AI calls are checked with the account's API key (decision 158). The two checks produce the origin tag used in the log (decision 162).
- The protocol (message formats, versions) becomes a contract between `battle_host` and the client. It is written down in M5 or M6, in the same package as the rules core.
- Interest management (fog per section) and the 5 Hz cadence are first-order levers. They are tuned with the scenario harness (M4 Issue 11), not by guessing.
