# Stack decision 1: simulation host

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 1). Rules: decisions 2 to 4, 160, 165, 167 to 172; MAP-04; COMBAT-01, COMBAT-02; RELIC-14; HQ-32; the 24-hour locks, 30-minute captures and victory timer of the specs.

## What the rules require
- An **authoritative** server for battles of 100+ players, up to about 1,000 units (decision 2).
- Battles **last days** and keep running while players are away (decision 3). Real time, no turns (decision 4).
- AP recovery at the battle's rate, 1 AP per hour by default (COMBAT-02, decision 172), morale per minute, timers from seconds to days (captures, recalls, locks, victory timer).
- Deterministic results: time is passed in and randomness comes from a seeded RNG (M4 conventions). A battle can be replayed from its inputs.
- The server gives its own orders through the API (AI-09, decision 165).

## Options
1. **Stateless functions per action** (the Appwrite Functions pattern of `backend/functions`). Battle state is reloaded on each call and timers need a scheduler. Latency and cold starts break real-time play, and fan-out to 100+ players is awkward. Rejected for battle state. Still fine for small admin tasks.
2. **Fixed tick for everything**: one long-running process ticks all units at 1 Hz. Simple, but every idle unit costs CPU for every tick.
3. **Lazy state with a slow tick**: each unit stores its state at its last update, plus its rates (AP recovery, morale drift). Its state at any time is computed on demand. A 1 Hz tick only handles what needs it: combat, vision, timers. Idle units cost nothing.
4. **Pure event sourcing with no tick**: every change scheduled as an event. Continuous AP and vision make it hard to keep correct.

## Choice
**Option 3, on long-running processes.** Each process hosts a set of battles that share a map. A battle stays on one process for its whole life. Recovery after a crash: load the latest snapshot, then replay the inputs logged after it (see stack decision 2).

AP is computed lazily: AP at time *t* is `min(ap_max, AP at the last update + hours since then × recovery_per_hour)`.

**Language: Dart**, for the simulation host and for the rules core (`battle_rules`, M3 and M4). Reasons:
- The rules core must run on the server and in the client (M4 acceptance). One Dart package serves both, so the numbers and rules cannot drift between two implementations.
- Dart compiles ahead of time to a native executable (`dart compile exe`), with no VM at run time.
- The workspace is already Dart and Flutter. The Appwrite Dart server SDK covers the admin side.
- Rejected: Go or Rust for speed (the client would need a second implementation of the rules, and the speed margin is not needed at this scale, see the load below). Node or TypeScript (same drift problem, and no shared code with the Flutter client).

## Load of one 1,000-unit battle over one day
Measured 2026-11-06 (M5 Issue 19, P-02 and P-03 of `milestones/performance-tests.md`): `battle_host`'s load script on the real map `saint_lo` (10 × 50 km, 246,000 objects), AOT, one core of the development laptop. Two teams of 500 units in sections of 16 face each other 100 m apart. Each unit spends the AP it recovers (1 AP an hour, 24,000 AP a day for the battle): half its orders are shots at the nearest enemy it sees (rifles, and machine guns for two soldiers of each section), half are 10 m moves; 40 % of the units open fire together at the start. Default recovery rate; a faster rate raises the order and log figures in proportion.

- **Orders:** about 7,300 a day (5,600 shots, 1,500 moves, 200 reloads), 7,800 log entries with the start. The opening burst sends up to 465 orders in one second.
- **CPU:** about **3 seconds of one core per simulated day** (36 µs per second on average, 0.2 ms at p99). The busiest second takes about 80 ms. The first orders on a map pay once for its path searches (2.3 s); the host prepares them when it loads the map. Server-managed sections (25 % of them) change nothing measurable.
- **Write-ahead log on disk:** each order waits for its own `fsync`, about 2.3 ms on the development laptop. That caps a battle at about 400 orders a second, and the burst's busiest second then takes about 1.1 s. Syncing the orders of one tick together (group commit) is the next step if a burst must fit in one second.
- **Memory:** one map takes about 340 MB loaded and 390 MB with its searches prepared, up to about 650 MB once paths across the map have been priced for the main movers. It is shared by all its battles. Each battle adds about 3 MB.
- **Battles per process:** the average load is small, so the limit is bursts that coincide. Ten battles that open fire in the same second took 0.9 s of one core. A process of one core holds **about 10 battles** whose bursts may meet, more if their starts are spread, in about 0.7 GB with one map.
- **Logs:** see `02-persistence.md`.

## Consequences
- Every input (order, time step, seed) must be logged before it is acknowledged, so that a crash does not lose an order (stack decision 2).
- The rules core is pure Dart with no Flutter import; the host and the client both depend on it (M4 Issue 1).
- **Hosting** (designer, 2026-11-01): each host process runs in a Docker container. In development everything is local, next to the self-hosted Appwrite. Live, Appwrite will probably be an Appwrite Cloud project, so the host containers run on a separate server, in the same region as that project. The provider is still open (designer, 2026-11-06): the image runs on any linux/amd64 Docker host.
- **Battle placement** (M5 Issue 19): a container serves fixed maps (`battle_host serve --map`). It claims each running battle of its maps that no host holds by writing its ID in the `host` column of the battle's row, and runs the battles whose row names it, recovering them from their snapshots after a restart. Two containers of one map may claim the same battle at once: the row keeps the last write and the other lets it go. When a battle ends, its host writes the result to its row, which starts `end_battle`.
- Bursts, not the daily average, set the peak: hundreds of orders a second for a few seconds when rested units open fire.
