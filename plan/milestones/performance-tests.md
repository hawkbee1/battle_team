# Performance tests (for later)

Status: **planned**. Not a milestone in the order M1 to M8: these tests are written when the code they measure exists, and they gate the milestones that depend on them. Each test has a **target** taken from a stack record, and an **estimate** that the test replaces with a measurement.

Conventions:
- Benchmarks are committed in the repository, run from the command line, and print one machine-readable line per run, so that two runs can be compared (the form of `examples/stress_bench` in flutter_scene).
- Timings are taken in profile mode, or in release mode for the server. Debug timings are not kept.
- Results are kept per commit. A regression is a change of more than 10 % against the last kept result.
- The scenario harness (M4 Issue 11) feeds the server tests with realistic battles.

## Tests and their targets

### P-01 Path search on a 10 × 50 km map (M3 Issue 6)
- Measure: time per path, and the AP cost of the fast search against the exact search.
- Target: at most 10 % more AP than the exact search (M3 Issue 6). With 10 m cells, on the host, compiled ahead of time: at most **50 ms** for a 2 km path and **500 ms** for a path across the map, once the search is prepared for the mover (designer, 2026-11-02).
- Measured (M3 Issue 6, `battle_pathfinding/benchmark_results`, synthetic map): median 15 ms for 2 km and about 150 ms across the map, at most 0.6 % more AP than the exact search.
- Measured again (M5 Issue 19, `battle_host/bin/load_test.dart`, the real map `saint_lo`, search data shared by the movers of the map, 20 paths of 2 km and 3 across the map per mover): 2 km paths take 21 to 30 ms at the median but up to 0.35 s (jeep) to 1.1 s (soldier). Across the map: jeep 0.23 s, soldier 1.3 to 2.5 s, tank 1.5 to 6.6 s, and one jeep path 7.5 s. **The across-map target is missed on real data**: hedges, rivers and towns make the fast search explore far more than on the synthetic map. A hierarchical search with precomputed paths between blocks is the next step.
- Where: `stack/01`, `stack/05`.

### P-02 Simulation host, one 1,000-unit battle over one simulated day (M2 Issue 1)
- Measure: CPU per tick at peak and on average, memory of one battle and of one map, and the number of battles one process holds.
- Target: the estimate in `stack/01` before the measurement: about 1 to 2 minutes of one core per simulated day, and bursts of up to a few thousand hit rolls per second for a few seconds.
- Measured (M5 Issue 8, `battle_map/benchmark_results`): one loaded synthetic 10 × 50 km map takes about 152 MB (40 MB ground, 111 MB objects), from `battle_pathfinding`'s navigation model. Packing it is left to a later optimisation (designer, 2026-11-04).
- Measured (M5 Issue 19, `battle_host/bin/load_test.dart`, AOT, the real map `saint_lo`; method and figures in `stack/01`): about 3 s of one core per simulated day; 36 µs per second on average, 0.2 ms at p99, about 80 ms in the busiest second of the opening burst (465 orders). The map takes about 340 MB loaded and 390 MB with its searches prepared; each battle adds about 3 MB; ten battles bursting in the same second take 0.9 s, so a one-core process holds about 10 battles. With the write-ahead log on disk, one `fsync` per order (2.3 ms on the development laptop) makes the burst's busiest second take 1.1 s. The first run took 14 s a day: two listeners scanned every unit for each section after each order; they now make one pass. Copying the state's unit map on each change is the next cost (about 30 % of an order).
- For M6: a section's machine guns fire 8 shots a second each, so the host's default rate limit (10 orders a second, 20 at once, per sender) throttles a section's burst. The load test lifts it.
- Where: `stack/01`.

### P-03 Battle log volume (M2 Issue 2)
- Measure: bytes per logged event, events per second, and the upload size per 10-second batch.
- Target: about 0.4 MB per battle per day, 2.4 MB at worst (estimates), in at most about 4,000 files a day (only 10-second intervals with new entries upload). The Appwrite limits must hold: the local instance in development, the Cloud plan's quotas live (`stack/02`).
- Measured (M5 Issue 19, the load test's 1,000-unit day on `saint_lo`): 7,837 entries (8,635 events), 115 bytes an entry, 0.86 MB a day; 836 uploads, 91 bytes compressed at the median, 301 on average, 73 kB for the opening burst's busiest interval; 0.24 MB uploaded a day. The snapshot of 1,000 units is 442 kB, 38 kB compressed. Under the targets.
- Measured (M5 Issue 15, the scripted battle of `battle_host`'s tests: 38 entries over 34 hours, 28 of them in the first 8 minutes, about 0.06 a second): 57 bytes an entry in the binary log, 54 an event; one upload per 10-second interval with entries, 1 to 9 entries each, 53 to 312 bytes compressed (151 on average; gzip adds about 20 bytes to each file, so one-entry uploads barely shrink). At 4,000 entries a day that is about 0.23 MB, 1.4 MB at 24,000: under the targets. A snapshot of its 17 units is 8.9 kB, 1.8 kB compressed. The Appwrite limits are not checked yet: the local instance was not reachable from the dev container.
- Where: `stack/02`.

### P-04 Network traffic of one section in a fight (M2 Issue 3)
- Measure: bytes per second to one section during a fight, and the late-join transfer size (visible state plus the delta layer).
- Target: about 7 to 9 kbit/s down per section during a fight, with bursts of about 35 kbit/s (rifles) to 430 kbit/s (machine guns, one event per shot) for a few seconds (estimates, `stack/03`); late-join transfer of a few hundred kilobytes, compressed.
- Where: `stack/03`.

### P-05 Rendering spike: 1,000 units on screen (M7, before the client)
- Measure: frame time in profile mode, split into UI thread and raster thread (the method of the `flutter_scene-performance` skill), for each platform: iOS, Android, macOS, Windows, Linux and Web.
- Devices: the designer's, listed in `stack/04` (iPhone 11, Pixel 6, the Mac, the main laptop under Linux and Windows, an old Lenovo laptop, a browser on both laptops). The slowest measured one becomes the reference device.
- Target: 16.6 ms per frame (60 fps) on desktop. Phones and web: at least 30 fps in top-down and 60 fps in first person (`stack/04`).
- Where: `stack/04`.

### P-06 Terrain tiles and map loading (M7)
- Measure: time to load a tile near the camera, time to first frame on a new map, memory of the tiles in view, and the time to add a crater patch or a construction to a tile in view (stack decision 5).
- Target: to be set after P-05. Adding a crater or a construction must fit in the frame budget or run off the frame.
- Where: `stack/05`.

### P-07 World change applied on the host (M3 Issue 5, `stack/05`)
- Measure: time from a construction or a destruction to its effect on the navigation model, and to its arrival at the clients.
- Target: under 10 ms on the host, under 1 second to the clients.
- Measured (M5 Issue 14, `battle_host/bin/world_change_bench.dart`, AOT): on a 10 × 50 km synthetic map, a battle's first change takes 7 to 8 ms (it copies the shared ground grid); each change after it takes 18 µs on average, 34 µs at p95, 353 µs at most. Under the 10 ms target.
- Where: `stack/05`, `stack/03`.

## Order
1. P-01 with M3 Issue 6 (done), and again with M5 when the host shares the search data between movers.
2. P-02 and P-03 with M5, when the simulation host exists.
3. P-04 with M6, when the protocol exists.
4. P-05 and P-06 as the first M7 task, before the client is built.
5. P-07 with M3 Issue 5 and again with M5.

## Open
- P-01 across the map on real data (above).
