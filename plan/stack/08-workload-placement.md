# Stack decision 8: where the work runs (client, serverless, server)

Status: **proposed** (milestone M2, Issue 8). Rules: decisions 1 to 3, 143, 158, 160 to 162; SOC-27; SOC-37, SOC-38. Stack facts about Appwrite were checked on 2026-11-01 against the Appwrite documentation.

## Principle
Authority does not move. Whatever decides an outcome (a move, a hit, a capture, AP, morale, the victory, a statistic, a medal) runs on the simulation host, or in a function that reads the host's logs. A client may run any work that only changes what is shown, or what is checked before it is sent. The host checks it again. A client's result is never trusted, so a modified client gains nothing.

## What Appwrite Functions offer
- **Runtimes:** Dart is supported. `backend/functions/ping` already runs one.
- **Triggers:** Appwrite events, HTTP calls, and cron schedules (the shortest interval is one minute).
- **Timeout:** 900 seconds maximum, the system-wide limit that `_APP_FUNCTIONS_TIMEOUT` sets on a self-hosted instance. A community thread reports that synchronous executions stop at 30 seconds whatever the timeout. **To verify on the project** before relying on it; long work runs asynchronously.
- **No persistent state:** a function has no connection that lasts between calls and no memory kept from one call to the next. It cannot hold a live battle or a WebSocket.

Sources: [Appwrite Functions documentation](https://appwrite.io/docs/products/functions/functions.md), [Appwrite self-hosting, function runtimes](https://appwrite.io/docs/advanced/self-hosting/configuration/functions.md), [community thread on the 30-second limit](https://appwrite.io/threads/1261111233646690427).

## Where the load actually is
The host estimate of decision 1 gives about 1 to 3 % of one core per battle on average. CPU is therefore not the main server cost. The main costs are the number of open connections and the bytes sent per section (decision 3, about 70 kbit/s down per section during a fight). Moving compute to the client would save little. The levers are interest management (fog per section), the 5 Hz cadence, and delta encoding.

## Placement
| Work | Runs in | Reason |
|---|---|---|
| Rendering, camera, interface, input, first-person control | Client | Display only |
| Interpolation, and AP and morale shown between updates (computed from the last state and the rates, decision 1) | Client | Lazy state makes this deterministic |
| Order check before sending (target in range, unit alive, action allowed), with `battle_rules` | Client, then host | A hint that saves a round trip; the host is the authority |
| Path preview for an order, with `battle_pathfinding` | Client, host recomputes | Preview only |
| Loading tiles and building terrain meshes near the camera | Client | Decision 5 |
| Drawing fog of war | Client draws what the host sent | The host filters (decision 3) |
| Live battle state, combat, vision, captures, timers, server-managed sections | Simulation host | Must stay in memory, in real time (decision 1) |
| Order acceptance, sequence number, write-ahead log | Simulation host | Decision 2 |
| Socket fan-out to 100+ players | Simulation host | Needs connections that last |
| Discord account linking (OAuth callback) | Function | One request, event-style |
| API key creation and revocation (hashed, shown once) | Function | Request-driven (decisions 158, 161) |
| Store and payment webhooks: verify the purchase, grant the cosmetic once | Function | Webhook; the grant is idempotent (decision 6) |
| Admin creates a war or a battle (SOC-16) | Function | Request-driven, written to Appwrite |
| Statistics and medals from uploaded logs | Function on a cron schedule, or on log upload | Batch work, off the live path (decision 143) |
| Discord gateway bridge | A separate long-running service, not a function | The gateway is a connection that lasts (decision 6) |
| Map validation | Dart command in CI and the map builder | Build-time work (decision 5) |

## How a serverless part would be built
1. The logic goes in a package in `packages/` (for example `battle_stats`), pure Dart, tested in the package with no Appwrite in the test.
2. The function in `backend/functions/<name>/` holds only an adapter (Adapter pattern, decision 7): it reads the event or request, calls the package, writes the result to Appwrite.
3. Packages a function uses are committed as a vendored copy, as `hawkbee_schema` is (decision 7).
4. Long work (the statistics batch) runs asynchronously, split per log file so that each run stays well inside the timeout.

## Consequences
- The live battle stays on the simulation host, so the serverless part is the glue around it: accounts, keys, purchases, admin requests and statistics.
- Statistics are computed from logs in batch, so their cost does not touch the live battle.
- Batch volume to check in M5: about 90 MB of log per battle per day (decision 1), read and summarised within the function timeout.
- Appwrite limits (write rate, file count) remain open (decision 2).
