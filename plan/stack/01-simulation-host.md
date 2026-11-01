# Stack decision 1: simulation host

Status: **proposed** (milestone M2, Issue 1). Rules: decisions 2 to 4, 160, 165; MAP-04; COMBAT-01; RELIC-14; HQ-32; the 24-hour locks, 30-minute captures and victory timer of the specs.

## What the rules require
- An **authoritative** server for battles of 100+ players, up to about 1,000 units (decision 2).
- Battles **last days** and keep running while players are away (decision 3). Real time, no turns (decision 4).
- Continuous AP regeneration (COMBAT-01), morale per minute, timers from seconds to days (captures, recalls, locks, victory timer).
- Deterministic results: time is passed in and randomness comes from a seeded RNG (M4 conventions). A battle can be replayed from its inputs.
- The server gives its own orders through the API (AI-09, decision 165).

## Options
1. **Stateless functions per action** (the Appwrite Functions pattern of `backend/functions`). Battle state is reloaded on each call and timers need a scheduler. Latency and cold starts break real-time play, and fan-out to 100+ players is awkward. Rejected for battle state. Still fine for small admin tasks.
2. **Fixed tick for everything**: one long-running process ticks all units at 1 Hz. Simple, but every idle unit costs CPU for every tick.
3. **Lazy state with a slow tick**: each unit stores its state at its last update, plus its rates (AP regen, morale drift). Its state at any time is computed on demand. A 1 Hz tick only handles what needs it: combat, vision, timers. Idle units cost nothing.
4. **Pure event sourcing with no tick**: every change scheduled as an event. Continuous AP and vision make it hard to keep correct.

## Choice
**Option 3, on long-running processes.** Each process hosts a set of battles that share a map. A battle stays on one process for its whole life. Recovery after a crash: load the latest snapshot, then replay the inputs logged after it (see decision 2).

**Language: Dart**, for the simulation host and for the rules core (`battle_rules`, M3 and M4). Reasons:
- The rules core must run on the server and in the client (M4 acceptance). One Dart package serves both, so the numbers and rules cannot drift between two implementations.
- Dart compiles ahead of time to a native executable (`dart compile exe`), with no VM at run time.
- The workspace is already Dart and Flutter. The Appwrite Dart server SDK covers the admin side.
- Rejected: Go or Rust for speed (the client would need a second implementation of the rules, and the speed margin is not needed at this scale, see the estimate). Node or TypeScript (same drift problem, and no shared code with the Flutter client).

## Load estimate for one 1,000-unit battle over one day
Assumptions (placeholders, to measure in M4 Issue 11 and M3 Issue 6):
- 1,000 units, 40 % in combat at peak, 10 % of the day in active fighting.
- Combat tick at 1 Hz. Each active unit checks its visible targets once per tick, with a spatial index (about 50 candidates per check).
- A shot every 3 seconds per active unit: about 130 hit rolls per second at peak.
- Paths re-computed about every 30 seconds per unit: about 30 path requests per second at peak, each about 1 ms with a hierarchical search.
- Morale updated per minute, not per tick: about 17 updates per second at most.
- AP regeneration is lazy: no work per tick.
- Server-managed units are checked every 30 minutes (decision 160): negligible.

Results:
- CPU: about 5 ms per tick at peak, about 1 ms on average over the day, plus about 3 % of one core for paths during fighting. Roughly **3 to 5 minutes of one core per simulated day**, or 1 to 3 % of one core on average. One core can host tens of such battles.
- Memory: the map is shared by all battles on it. A 10 × 50 km map at 10 m cells is 1,000 × 5,000 = 5 million cells, about 4 bytes each: about 20 MB, plus about 15 MB for about 200,000 objects. Each battle adds about 1 MB for its units. About 20 battles per process would fit in about 0.6 GB. The figure of 10 m per cell is a proposal (see decision 5).
- Logs: about 10 events per second on average, about 100 bytes each: about **90 MB of log per battle per day**.

## Consequences
- Every input (order, time step, seed) must be logged before it is acknowledged, so that a crash does not lose an order (decision 2).
- The rules core is pure Dart with no Flutter import; the host and the client both depend on it (M4 Issue 1).
- Battle placement (which process hosts which battle) is a server concern, not a rule. It is recorded when it is built (M5).
- Benchmarks are required before the process size is fixed: the figures above are estimates, not measurements.
