# Stack decision 2: persistence

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 2). Rules: decisions 3, 26 to 28, 143, 161, 162, 167 to 172; HQ-20; the war and section rules of `specs/40-newcomers-and-social.md` and `specs/50-hq.md`; AI-04, AI-05.

## What the rules require
- **Battle state**: units, sections, relics, terrain changes (the delta layer, MAP-06, MAP-08), timers. Kept while the battle runs (decision 3).
- **Wars, sections, guilds, accounts, purchases, medal definitions**: long-lived and relational, with low write rates.
- **Battle logs**: every action. Statistics and medals are computed from them (decision 143).
- **API keys**: one per account, stored so that they can be revoked by the user or an admin (decisions 158, 161). Each action records whether a player or an AI did it (decision 162).

## Volumes
Estimated 2026-11-01 from the AP rules (stack decision 1 has the derivation). Default recovery, one battle:

| Case | Log events a day | Size a day |
|---|---|---|
| Typical: half attacks, half moves (10 m orders) | about 4,000 | about 0.4 MB |
| Worst: 1 m orders with machine guns | about 24,000 | about 2.4 MB |
| Measured (M5 Issue 19, 1,000 units on `saint_lo`, opening burst included) | 7,837 entries, 8,635 events | 0.86 MB, 0.24 MB uploaded compressed |

- Battle-start burst: up to 5,000 events, once per battle.
- What is logged: inputs (orders with their time, seeds) and, in the same entry as each attack, its outcome (hit or miss, damage, kill), so the statistics batch reads the log without replaying the battle. Tick times are implicit (1 Hz from the battle start) and are not logged.
- Write rate: about 0.05 events per second per battle (typical), 0.3 at worst. About 5 to 28 per second for 100 battles.
- Statistics: one batch a day per battle, reading about 0.4 MB. No timeout concern.

## Options
1. **Everything in Appwrite** (Databases or TablesDB, Storage) of the shared Hawkbee project. Simplest, and already the project's backend. The write rate is now 5 to 28 log writes per second for 100 battles, which is low, but the Appwrite limits of the Hawkbee project have **not been checked**.
2. **A dedicated database (for example PostgreSQL) for battle state and logs, Appwrite for accounts.** Handles any write rate and gives relational queries for statistics. Adds a new service to run, back up and secure. Not needed at the current volumes.
3. **Hybrid.** Appwrite holds the low-write data: accounts, guilds, wars, sections, purchases, medal definitions, API keys (hashed), admin roles. Battle state lives in memory on the simulation host, with snapshots and write-ahead logs on its local disk. The logs are uploaded in batches to Appwrite Storage. A batch job computes statistics and medals from the logs and writes the results back to Appwrite tables.

## Choice
**Option 3 (hybrid).** Reasons: it keeps everything in the Appwrite project the app already uses for the low-write data, and it keeps the hot path (orders, state, write-ahead log) on the host. Statistics come from logs in batch, which matches decision 143.

Write path for one battle:
1. An order arrives. The host appends it to its local write-ahead log and calls `fsync`. Orders are rare (about 0.05 a second), so the `fsync` costs little.
2. Only then does the host acknowledge the order to the sender.
3. Every 10 seconds, if there are new log entries, the host uploads them as one compressed file to Appwrite Storage. An interval with no new entry uploads nothing (designer, 2026-11-01).
4. Every 5 minutes, the host writes a snapshot of the battle state, also to Appwrite Storage.

Recovery: load the latest snapshot, replay the uploaded and local logs after it. Both the snapshot and the replay are deterministic (stack decision 1).

## Consequences
- **Known gap, accepted by the designer (2026-10-31)**: if a host machine is lost together with its local disk, the inputs of the last 10 seconds may be lost. Accepted until the first real battles (M8). The alternative is to replicate the write-ahead log before acknowledging, which costs latency. Live, the host and Appwrite Cloud are on different machines, so the uploads cover the loss of the host machine; in development everything is local (stack decision 1, hosting).
- **File count.** Only a 10-second interval with new entries uploads a file, so a battle makes at most about 4,000 files a day at typical volumes, fewer when events cluster in fights (8,640 if every interval uploaded). Size is not a concern. The designer kept the 10-second interval (2026-11-01), so the accepted loss window stays at 10 seconds.
- **Appwrite limits.** In development, the settings of the local instance. Live, the quotas of the Appwrite Cloud plan (storage, bandwidth, database operations, function executions), checked when the plan is chosen, before M5 goes live. Operation counts matter more than bytes.
- Battle logs are the source of statistics and medals (decision 143), so their format is a data contract: it is versioned from the start.
- If log volume ever outgrows Appwrite Storage, the next step is a dedicated database (option 2). At the current volumes this trigger is far away.
- Every action in the log carries its origin: player, AI or server (decisions 162, 166).
