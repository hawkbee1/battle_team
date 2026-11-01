# Milestone 2: technical stack

Goal: choose the technical stack **from the rules**. Each choice is written down as a decision record. **No code is written in this milestone, nor before it ends**: specs and data never depend on the stack, code always does. Nothing in the current code is a stack decision until this milestone confirms it (Q-GEN-01).

Each issue below is ready to be created as a GitHub issue in the milestone "M2 – Technical stack". Labels: `stack` plus the one listed. Each issue ends with a decision record in `plan/stack/`, one file per issue: options considered, choice, reasons, and consequences for the later milestones.

## What the stack must support (from the specs)
- Persistent battles that last days and keep running while players are away (decision 3), in real time (decision 4).
- 100+ players per battle (decision 2), 2 to 5 teams, maps up to 10 × 50 km (MAP-04).
- An authoritative server: fog of war per section (MAP-29), hit resolution with a seeded RNG (M4).
- Timers from seconds to days: AP recovery, morale per minute, 30-minute captures, 6-hour recalls, 24-hour locks and the victory timer.
- A world that changes during a battle and must reach late joiners (MAP-06, MAP-08).
- Top-down command and first-person control of a unit (decision 5).
- The rules core (M4) and pathfinding (M3) running where the rules are resolved.
- Discord account linking and team chat synced with Discord (SOC-37, SOC-38); cosmetics bought with real money (SOC-27); admins who create wars and battles (SOC-16).

---

## Issue 1: Simulation host
Label: `server`

What runs an authoritative battle: how the clock advances (ticks or scheduled events), how one battle runs for days, how it recovers from a crash, how many battles run at once. Also the language and tools of the code that runs there: the rules core (M4) and pathfinding (M3).

Acceptance criteria:
- Decision record.
- An estimate of the load of a 1,000-unit battle over one day (AP, movement, morale, captures, timers, AI from M1), with its reasoning.

## Issue 2: Persistence
Label: `server`

Where battle state, the world delta layer, wars, sections and logs are stored; how statistics and medals are computed from the logs (decision 143).

Acceptance criteria:
- Decision record.

## Issue 3: Networking
Label: `network`

How orders and state updates reach 100+ players in real time; fog of war filtered per section on the server; alerts (RELIC-10); late joiners receiving the delta layer (MAP-08).

Acceptance criteria:
- Decision record.
- An estimate of the update traffic of one section during a fight.

## Issue 4: Client and 3D rendering
Label: `client`

Engine and renderer for the top-down camera and first-person control; target platforms and their frame budget.

Acceptance criteria:
- Decision record.
- The slowest target device and its frame budget are named.

## Issue 5: Map format and authoring
Label: `map`

Map format, authoring workflow and tools, loader on server and client (MAP-05), conversion to the navigation model of pathfinding (M3); performance budgets for world changes (Q-MAP-09) and pathfinding (M3 Issue 6).

Acceptance criteria:
- Decision record.
- How a map becomes the navigation model of pathfinding (M3) is described.

## Issue 6: Accounts and external services
Label: `services`

Player accounts, Discord account linking and team chat sync (SOC-37, SOC-38), payments for cosmetics (SOC-27), admin tools for wars and battles (SOC-16).

Acceptance criteria:
- Decision record.

## Issue 7: Engineering principles and package layout
Label: `engineering`

SOLID principles, Gang of Four patterns and their use in Dart, the VGV tooling used to build and test, and the location of every package (`packages/`, never under `apps/battle_team/`).

Acceptance criteria:
- Decision record.
- Each planned package named, with the milestone that creates it.

## Issue 8: Where the work runs (client, serverless, server)
Label: `server`

Which work runs on the client, in serverless functions, and on the simulation host, so that the server load stays low without moving any authority off the host. Checks the Appwrite Functions limits (runtimes, timeouts, cron) on the project before use.

Acceptance criteria:
- Decision record.
- Each function planned, with the package it calls.

## Done when
- Every issue has its decision record, and Q-GEN-01 points to them.
- M3 and M4 name their language, project layout and tools.
- The outline of M5 to M7 at the end of `milestones/m4-rules-core.md` is rewritten for the chosen stack.

## Status (2026-11-01)
- The eight records exist in `plan/stack/` and are **proposed**. The three conditions above are met; M2 ends when the designer confirms the records.
- Open questions that block M3 or M4: Q-REL-12 and Q-REL-13 (M3 Issue 4, M4 Issue 10). The others still open (Q-CBT-31 to Q-CBT-33, Q-UNIT-21, Q-UNIT-22) are about placeholders or M5.
