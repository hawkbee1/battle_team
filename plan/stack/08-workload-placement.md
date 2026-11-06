# Stack decision 8: where the work runs (client, serverless, server)

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 8). Rules: decisions 2, 3, 143, 157, 158, 161, 162, 167 to 172, 183; COMBAT-14; SOC-16, SOC-27, SOC-37, SOC-38. The Appwrite facts below were checked on 2026-11-01 against the Appwrite documentation.

## Principle
Authority does not move. Whatever decides an outcome (a move, a hit, a capture, AP, morale, the victory, a statistic, a medal) runs on the simulation host, or in a function that reads the host's logs. A client may run any work that only changes what is shown, or what is checked before it is sent. The host checks it again. A client's result is never trusted, so a modified client gains nothing.

## What Appwrite Functions offer
- **Runtimes:** Dart is supported. `backend/functions/ping` already runs on `dart-3.13`.
- **Triggers:** Appwrite events, HTTP calls, and cron schedules (the shortest interval is one minute).
- **Timeout:** 900 seconds maximum, the system-wide limit that `_APP_FUNCTIONS_TIMEOUT` sets on a self-hosted instance. A community thread reports that synchronous executions stop at 30 seconds whatever the timeout. **To verify on the project** before relying on it; long work runs asynchronously.
- **Self-hosted versus Cloud:** these facts were checked for a self-hosted instance (development). Live, on Appwrite Cloud, the plan's limits apply (timeout, executions, cron); they are checked when the plan is chosen.
- **No persistent state:** a function has no connection that lasts between calls and no memory kept from one call to the next. It cannot hold a live battle or a WebSocket.

Sources: [Appwrite Functions documentation](https://appwrite.io/docs/products/functions/functions.md), [Appwrite self-hosting, function runtimes](https://appwrite.io/docs/advanced/self-hosting/configuration/functions.md), [community thread on the 30-second limit](https://appwrite.io/threads/1261111233646690427).

## Where the load is
The AP rules bound the work (stack decision 1). A 1,000-unit battle has about 24,000 AP a day to spend: about 4,000 logged events a day. Measured (M5 Issue 19): about 7,800 log entries with the opening burst and about 3 seconds of one core per simulated day. The peaks are short bursts when rested units open fire. The network costs are the open connections and those bursts (stack decision 3). Moving compute to the client would save little. The levers are fog per section, grouping shots per unit per tick, and the number of moving vehicles in view.

## Placement
| Work | Runs in | Reason |
|---|---|---|
| Rendering, camera, interface, input, first-person control | Client | Display only |
| Interpolation, and AP shown between updates (AP recovers at the battle's constant rate, so the client computes it from the last value) | Client | Deterministic from the last update |
| Order check before sending (target in range, unit alive, action allowed, enough AP), with `battle_rules` | Client, then host | A hint that saves a round trip; the host is the authority |
| Path for an order, with `battle_pathfinding` | Client computes, host checks it cell by cell (cost, passability, slope limit) | Checking is cheaper than searching again |
| First-person shot: aim direction and fire time | Client sends them; the host applies the spread, flies and traces the projectile (decision 183) | The client only draws the shot, so it cannot choose a hit |
| Loading tiles and building terrain meshes near the camera | Client | Stack decision 5 |
| Drawing fog of war | Client draws what the host sent | The host filters (stack decision 3) |
| Live battle state: combat, vision, morale, captures, pots, timers, server-managed sections | Simulation host | Must stay in memory, in real time. Morale changes through events that depend on positions the section may not see, so the client cannot compute it |
| Order acceptance, sequence number, write-ahead log | Simulation host | Stack decision 2 |
| Socket fan-out to 100+ players | Simulation host | Needs connections that last |
| Discord account linking | Appwrite OAuth if it offers a Discord provider; otherwise a function as the OAuth callback | Stack decision 6 |
| API keys, Stripe webhook, war and battle setup, end of battle, guild requests, statistics, notifications | Functions (table below) | Request-, event- or schedule-driven work around the battle, written to Appwrite |
| Discord gateway bridge | A separate long-running service, not a function | The gateway is a connection that lasts (stack decision 6) |
| Map validation | Dart command in CI and the map builder | Build-time work (stack decision 5) |

## Functions
Designer, 2026-11-01. Each function is an adapter around the package it calls (see below).

| Function | Trigger | Package |
|---|---|---|
| `api_keys`: create (hashed, shown once) and revoke (decisions 158, 161) | HTTP | `battle_protocol` (key format, shared with the host's check) |
| `payment_webhook`: verify the Stripe event, grant the cosmetic once (stack decision 6) | Webhook | none: an adapter, with a write keyed by the payment ID |
| `create_war`, `create_battle` (admins, SOC-16), with team balancing by team power (decision 103) | HTTP | `battle_rules` |
| `end_battle`: carry the sections over to the next battle of the war, record the result | Event: battle ended | `battle_rules` |
| `guild_requests`: create, apply, accept or refuse a trainee, between battles (during a battle the host handles them) | HTTP | `battle_rules` |
| `daily_stats`: statistics and medals from the uploaded logs (decision 143), about 0.4 MB per battle-day | Cron, daily per battle | `battle_stats` |
| `notify`: push notifications (war announced, battle starting) through Appwrite Messaging | Event | none |
| `discord_link_callback`: only if Appwrite's Discord provider cannot link an existing account | HTTP | none |

## Client trust
No platform lets the host prove that a client is genuine (checked 2026-11-01): App Attest on iOS is strong, Play Integrity on Android is medium (rooted phones pass its lower tiers), macOS has almost none, and Windows, Linux and the web have none. Anything a client computes is therefore a proposal the host checks.
- Attestation, where it exists, is recorded with the session as a signal, never a gate.
- Fog of war is filtered on the host (stack decision 3): a client never receives what its section cannot see.
- First-person shots are traced on the host; the client sends only the aim direction and the fire time.
- The host checks every order: AP, range, line of sight, visibility, rate of fire.
- AI agents play through the same API (decision 157), so automation is not cheating; only breaking a rule or seeing hidden information is, and the host prevents both.
- The daily statistics function flags hit rates far above the norm, for the moderation tools of M8.

Sources: [Apple, DCAppAttestService.isSupported](https://developer.apple.com/tutorials/data/documentation/devicecheck/dcappattestservice/issupported.md), [OWASP MASTG, Play Integrity](https://mas.owasp.org/MASTG/knowledge/android/MASVS-RESILIENCE/MASTG-KNOW-0035/).

## How a serverless part would be built
1. The logic goes in a package in hawkbee `packages/` (for example `battle_stats`), pure Dart, tested in the package with no Appwrite in the test.
2. The function in `backend/functions/<name>/` holds only an adapter (Adapter pattern, stack decision 7): it reads the event or request, calls the package, writes the result to Appwrite.
3. Packages a function uses are committed as a vendored copy, as `hawkbee_schema` is (stack decision 7).
4. Work longer than a few seconds runs asynchronously. The statistics batch reads about 0.4 MB per battle-day, well inside the timeout.

## Consequences
- The live battle stays on the simulation host, so the serverless part is the glue around it: keys, purchases, battle setup and end, guilds between battles, statistics and notifications.
- The war, section and guild rules a function needs (team power, balancing, carry-over, guilds) live in `battle_rules`, not in `battle_host`, so a function can call them. M5 adds them there.
- Statistics are computed from logs in batch, so their cost does not touch the live battle.
- Appwrite limits: the local instance's settings in development, the Cloud plan's quotas live (stack decision 2).
