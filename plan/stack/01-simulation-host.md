# Stack decision 1: simulation host

Status: **proposed** (milestone M2, Issue 1). Rules: decisions 2 to 4, 160, 165, 167 to 172; MAP-04; COMBAT-01, COMBAT-02; RELIC-14; HQ-32; the 24-hour locks, 30-minute captures and victory timer of the specs.

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
- Rejected: Go or Rust for speed (the client would need a second implementation of the rules, and the speed margin is not needed at this scale, see the estimate). Node or TypeScript (same drift problem, and no shared code with the Flutter client).

## Load estimate for one 1,000-unit battle over one day
Assumptions (placeholders, to measure in M4 Issue 11 and M3 Issue 6). They hold for the default recovery rate; a special event with a faster rate raises the hit-roll and log figures in proportion.
- 1,000 units, each with at most 30 AP and 1 AP per hour of recovery. The battle has about **24,000 AP a day** to spend, after the starting pools of 30,000 AP.
- Every logged move or attack spends AP. Typical mix: half the events are attacks (rifles, 2 AP per shot), half are moves (10 m orders, 10 AP each). That gives about **4,000 events a day** (table in `02-persistence.md`).
- Combat tick at 1 Hz. Units in contact check their visible targets each tick, with a spatial index (about 50 candidates per check).
- One path request per move order: about 2,000 a day, about 1 ms each with a hierarchical search.
- Morale updated per minute, not per tick: about 17 updates per second.
- AP is lazy (see Choice): no work per tick.
- Server-managed units are checked every 30 minutes (decision 160): negligible.
- First-person shots are traced on the host (decision 183): one ray march per shot against terrain, objects and nearby hit volumes, well under a millisecond each, within the shot counts below.

Results:
- **Hit rolls:** typical about 2,000 shots a day, 0.02 per second on average. The AP budget caps it at 12,000 rifle shots a day (0.14 per second), or 24,000 machine-gun shots a day (0.28 per second).
- **Bursts:** a rested unit holds 30 AP: 15 rifle shots, fired in about 22 s (40 rounds a minute, one 3 s reload), or 30 machine-gun shots, fired in about 4 s. If 400 units (40 %) open fire together, that is about **270 hit rolls per second for about 20 s with rifles**, or about **3,300 per second for about 4 s with machine guns**. The same burst happens whenever rested units meet, not only at battle start.
- **CPU:** path requests and hit rolls cost little. Target scans for units in contact (about 1 ms per tick on average) dominate. Total about **1 to 2 minutes of one core per simulated day**. Scans gated on units that have the AP for a shot would lower it further. Measured in M4 Issue 11.
- **Memory:** the map is shared by all battles on it. A 10 × 50 km map at 10 m cells is 1,000 × 5,000 = 5 million cells, about 4 bytes each: about 20 MB, plus about 15 MB for about 200,000 objects. Each battle adds about 1 MB for its units. About 20 battles per process would fit in about 0.6 GB. The figure of 10 m per cell is a proposal (see stack decision 5).
- **Logs:** about 4,000 events a day at about 100 bytes each: **about 0.4 MB of log per battle per day**. Worst case (1 m orders): 24,000 events, 2.4 MB. The battle-start burst adds up to 5,000 events once. Details in `02-persistence.md`.

## Consequences
- Every input (order, time step, seed) must be logged before it is acknowledged, so that a crash does not lose an order (stack decision 2).
- The rules core is pure Dart with no Flutter import; the host and the client both depend on it (M4 Issue 1).
- Battle placement (which process hosts which battle) is a server concern, not a rule. It is recorded when it is built (M5).
- Bursts, not the daily average, set the peak: up to a few thousand hit rolls per second for a few seconds when rested units open fire.
- Benchmarks are required before the process size is fixed: the figures above are estimates, not measurements.
