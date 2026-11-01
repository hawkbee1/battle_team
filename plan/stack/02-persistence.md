# Stack decision 2: persistence

Status: **proposed** (milestone M2, Issue 2). Rules: decisions 3, 26 to 28, 143, 161, 162; HQ-20; the war and section rules of `specs/40-newcomers-and-social.md` and `specs/50-hq.md`; AI-04, AI-05.

## What the rules require
- **Battle state**: units, sections, relics, terrain changes (the delta layer, MAP-06, MAP-08), timers. Kept while the battle runs (decision 3).
- **Wars, sections, guilds, accounts, purchases, medal definitions**: long-lived and relational, with low write rates.
- **Battle logs**: every action. Statistics and medals are computed from them (decision 143).
- **API keys**: one per account, stored so that they can be revoked by the user or an admin (decisions 158, 161). Each action records whether a player or an AI did it (decision 162).

## Options
1. **Everything in Appwrite** (Databases or TablesDB, Storage) of the shared Hawkbee project. Simplest, and already the project's backend. The write rate of battle state and logs is high: about 10 writes per second per battle, so about 1,000 per second with 100 battles. That is likely beyond what a shared managed API should take. The Appwrite limits of the Hawkbee project have **not been checked**.
2. **A dedicated database (for example PostgreSQL) for battle state and logs, Appwrite for accounts.** Handles the write rate and gives relational queries for statistics. Adds a new service to run, back up and secure.
3. **Hybrid.** Appwrite holds the low-write data: accounts, guilds, wars, sections, purchases, medal definitions, API keys (hashed), admin roles. Battle state lives in memory on the simulation host, with snapshots and write-ahead logs on its local disk. The logs are uploaded in batches to Appwrite Storage. A batch job computes statistics and medals from the logs and writes the results back to Appwrite tables.

## Choice
**Option 3 (hybrid).** Reasons: it keeps everything in the Appwrite project the app already uses for the low-write data, and it keeps the hot path out of any database. Statistics come from logs in batch, which matches decision 143.

Write path for one battle:
1. An order arrives. The host appends it to its local write-ahead log and calls `fsync`.
2. Only then does the host acknowledge the order to the sender.
3. Every 10 seconds, the host uploads the new log entries as one compressed file to Appwrite Storage.
4. Every 5 minutes, the host writes a snapshot of the battle state, also to Appwrite Storage.

Recovery: load the latest snapshot, replay the uploaded and local logs after it. Both the snapshot and the replay are deterministic (decision 1).

## Consequences
- **Known gap, accepted by the designer (2026-10-31)**: if a host machine is lost together with its local disk, the inputs of the last 10 seconds may be lost. Accepted until the first real battles (M8). The alternative is to replicate the write-ahead log before acknowledging, which costs latency.
- Appwrite limits (write rate, file count, storage per battle) must be checked against the Hawkbee project before implementation. This record assumes they are enough for the batch volumes above.
- Battle logs are the source of statistics and medals (decision 143), so their format is a data contract: it is versioned from the start.
- If log volume outgrows Appwrite Storage, the next step is a dedicated database (option 2). This record names that as the trigger to revisit.
- Every action in the log carries its origin: player, AI or server (decisions 162, 166).
