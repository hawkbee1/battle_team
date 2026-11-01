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
- Target: at most 10 % more AP than the exact search (M3 Issue 6). Time per path to be set from the first measurement; the estimate is about 1 ms.
- Where: `stack/01`, `stack/05`.

### P-02 Simulation host, one 1,000-unit battle over one simulated day (M2 Issue 1)
- Measure: CPU per tick at peak and on average, memory of one battle and of one map, and the number of battles one process holds.
- Target: the estimate in `stack/01` (about 1 to 2 minutes of one core per simulated day; bursts of up to a few thousand hit rolls per second for a few seconds). Replace with the measured figures.
- Where: `stack/01`.

### P-03 Battle log volume (M2 Issue 2)
- Measure: bytes per logged event, events per second, and the upload size per 10-second batch.
- Target: about 0.4 MB per battle per day, 2.4 MB at worst (estimates), in about 8,640 ten-second files. The Appwrite file-count and storage limits must hold at that number (`stack/02`).
- Where: `stack/02`.

### P-04 Network traffic of one section in a fight (M2 Issue 3)
- Measure: bytes per second to one section during a fight, and the late-join transfer size (visible state plus the delta layer).
- Target: about 7 to 9 kbit/s down per section during a fight, with bursts of about 35 kbit/s (rifles) to 430 kbit/s (machine guns, one event per shot) for a few seconds (estimates, `stack/03`); late-join transfer of a few hundred kilobytes, compressed.
- Where: `stack/03`.

### P-05 Rendering spike: 1,000 units on screen (M7, before the client)
- Measure: frame time in profile mode, split into UI thread and raster thread (the method of the `flutter_scene-performance` skill), for each platform: iOS, Android, macOS, Windows, Linux and Web.
- Devices: three candidates per platform. The slowest measured one becomes the reference device for the budget (`stack/04`). The designer chooses the devices to test.
- Target: 16.6 ms per frame (60 fps) on desktop. Phone and web targets: set after the first measurements.
- Where: `stack/04`.

### P-06 Terrain tiles and map loading (M7)
- Measure: time to load a tile near the camera, time to first frame on a new map, memory of the tiles in view, and the time to rebuild a tile after a crater or a construction.
- Target: to be set after P-05. Tile rebuild must fit in the frame budget or run off the frame.
- Where: `stack/05`.

### P-07 World change applied on the host (M3 Issue 5, `stack/05`)
- Measure: time from a construction or a destruction to its effect on the navigation model, and to its arrival at the clients.
- Target: under 10 ms on the host, under 1 second to the clients.
- Where: `stack/05`, `stack/03`.

## Order
1. P-01 with M3 Issue 6, when the path search exists.
2. P-02 and P-03 with M5, when the simulation host exists.
3. P-04 with M6, when the protocol exists.
4. P-05 and P-06 as the first M7 task, before the client is built.
5. P-07 with M3 Issue 5 and again with M5.

## Open
- The devices for P-05 (designer's choice).
- The budget for phones and the web (after P-05).
- The number of battles per process (after P-02).
