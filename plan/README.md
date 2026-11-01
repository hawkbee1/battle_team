# BattleTeam plan

This folder holds the game specification and the work plan. The rest of the repository holds the current app scaffold, which is not a stack decision (see M2).

## Layout
| Path | Content |
|---|---|
| `specs/*.md` | Rules of the game, written to teach it. One file per area. |
| `data/*.yaml` | Numbers (stats, costs, tables): `units`, `combat`, `terrain`, `battle` (battle-setting defaults), `economy`, `medals`. Code loads these files; numbers are never written in code. |
| `milestones/*.md` | Implementation milestones and their issues, each naming the rule IDs it implements. |
| `stack/*.md` | Technical stack decision records (milestone M2), one per issue. Proposals until confirmed. |
| `milestones/performance-tests.md` | Performance tests, written with the code they measure; each has a target from a stack record. |
| `specs/95-open-questions.md` | Master list of open questions. This is the to-do / done list of the spec phase. |
| `specs/96-design-risks.md` | Design risks noticed in reviews and not yet addressed. |

## Spec status
Each spec moves through: **draft** → **review** → **ready**. *Ready* means the area is complete enough for coding agents to implement it, and changes go through the open-questions list.

| Spec | Area | Status |
|---|---|---|
| `specs/00-overview.md` | Index and record of decisions | ready |
| `specs/10-map-and-terrain.md` + `data/terrain.yaml` | Maps, terrain, movement, water, line of sight | ready |
| `specs/20-units-and-progression.md` + `data/units.yaml` | Unit stats, capabilities, XP, skill trees | ready |
| `specs/30-special-units-and-victory.md` | Relics, capture, push, victory | ready |
| `specs/40-newcomers-and-social.md` | Newcomer placement, wars, communication, sections | ready |
| `specs/80-ai-and-automation.md` | Section AI, AI agents through the API, server-managed sections (milestone M1) | ready |
| `specs/50-hq.md` | HQ, manager, storage | ready |
| `specs/60-economy.md` | Money: earning, spending, transfers | ready |
| `specs/70-combat-and-ap.md` + `data/combat.yaml` | AP, weapons, hits, damage, morale, prisoners | ready |
| `specs/90-research-topic-priority.md` | Research note (input, not a decision) | reference |
| `specs/96-design-risks.md` | Design risks | tracking |

## How we work

### Phase 1: specification
1. Decisions come from Q&A with the game designer and are recorded in the matching spec file and in `specs/00-overview.md` (numbered decisions).
2. Every open question gets an ID in `specs/95-open-questions.md` and is ticked when decided, with the number of the decision that settles it.
3. When an area has no blocking open question left, its status goes to **review**, then **ready** once the designer agrees.
4. Each rule in a *ready* spec has a short ID so code and tests can reference it. Prefixes: `MAP` (10), `UNIT` (20), `RELIC` (30), `SOC` (40), `HQ` (50), `ECO` (60), `COMBAT` (70), `AI` (80).
   - IDs are **stable**: never renumbered, never reused. A new rule takes the next free number of its spec. A removed rule is simply deleted.
   - A rule change is a new decision in `specs/00-overview.md`; the rule text is updated in place and keeps its ID.

### Phase 2: milestones
Specs and data never depend on the technical stack. **No code is written before the stack is chosen (M2).**

Milestones, in order:
1. **M1 – Section AI and automation** (`milestones/m1-ai-and-automation.md`): rules for what units do on their own. A discussion with the designer; no code.
2. **M2 – Technical stack** (`milestones/m2-technical-stack.md`): the stack is chosen from the rules, not taken from the current code. No code.
3. **M3 – Pathfinding** (`milestones/m3-pathfinding.md`): paths for every movement class, headless.
4. **M4 – Rules core** (`milestones/m4-rules-core.md`): AP, movement cost, vision and combat resolution, loading `data/*.yaml`, covered by unit tests. No rendering, no network.
5. **M5 to M7**: server-side persistence, networking, then the client (outline at the end of `milestones/m4-rules-core.md`).
6. **M8 – Revision after real battles** (`milestones/m8-revision-after-real-battles.md`): moderation tools and the points left to watch in real battles.
