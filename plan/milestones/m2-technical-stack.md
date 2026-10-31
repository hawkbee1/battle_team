# Milestone 2: technical stack

Goal: choose the technical stack **from the rules**. Each choice is written down as a decision record and, when it is risky, backed by a small spike. Nothing in the current code is a stack decision until this milestone confirms it (Q-GEN-01).

Each issue below is ready to be created as a GitHub issue in the milestone "M2 – Technical stack". Labels: `stack` plus the one listed. Each issue ends with a decision record in `plan/stack/`, one file per issue: options considered, choice, reasons, and consequences for the later milestones.

## What the stack must support (from the specs)
- Persistent battles that last days and keep running while players are away (decision 3), in real time (decision 4).
- 100+ players per battle (decision 2), 2 to 5 teams, maps up to 10 × 50 km (MAP-04).
- An authoritative server: fog of war per section (MAP-29), hit resolution with a seeded RNG (M1).
- Timers from seconds to days: AP regen, morale per minute, 30-minute captures, 6-hour recalls, 24-hour locks and the victory timer.
- A world that changes during a battle and must reach late joiners (MAP-06, MAP-08).
- Top-down command and first-person control of a unit (decision 5).
- The rules core (M1) and pathfinding (M0) running where the rules are resolved.
- Discord account linking and team chat synced with Discord (SOC-37, SOC-38); cosmetics bought with real money (SOC-27); admins who create wars and battles (SOC-16).

---

## Issue 1: Simulation host
Label: `server`

What runs an authoritative battle: how the clock advances (ticks or scheduled events), how one battle runs for days, how it recovers from a crash, how many battles run at once.

Acceptance criteria:
- Decision record.
- Spike: the M1 rules core plays a scripted battle of 1,000 units over one simulated day; time and memory are recorded.

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
- Spike measuring the update traffic of one section during a fight.

## Issue 4: Client and 3D rendering
Label: `client`

Engine and renderer for the top-down camera and first-person control; target platforms and their frame budget.

Acceptance criteria:
- Decision record.
- Spike: one unit in first person and the same scene from the top-down camera, on the slowest target device.

## Issue 5: Map format and authoring
Label: `map`

Map format, authoring workflow and tools, loader on server and client (MAP-05), conversion to the M0 abstract map; performance budgets for world changes (Q-MAP-09) and pathfinding (M0 Issue 6).

Acceptance criteria:
- Decision record.
- A small authored test map loads into the M0 pathfinding.

## Issue 6: Accounts and external services
Label: `services`

Player accounts, Discord account linking and team chat sync (SOC-37, SOC-38), payments for cosmetics (SOC-27), admin tools for wars and battles (SOC-16).

Acceptance criteria:
- Decision record.

## Done when
- Every issue has its decision record, and Q-GEN-01 points to them.
- The outline of M3 to M5 at the end of `milestones/m1-rules-core.md` is rewritten for the chosen stack.
