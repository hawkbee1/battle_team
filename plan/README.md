# BattleTeam plan

This folder holds the game specification and the work plan. The Flutter/Flame code lives in the rest of the repository.

## Layout
| Path | Content |
|---|---|
| `specs/*.md` | Rules of the game, written to teach it. One file per area. |
| `data/*.yaml` | Numbers (stats, costs, tables): `units`, `combat`, `terrain`, `battle` (battle-setting defaults), `economy`, `medals`. Code loads these files; numbers are never written in code. |
| `milestones/*.md` | Implementation milestones and their issues, each naming the rule IDs it implements. |
| `specs/95-open-questions.md` | Master list of open questions. This is the to-do / done list of the spec phase. |

## Spec status
Each spec moves through: **draft** → **review** → **ready**. *Ready* means the area is complete enough for coding agents to implement it, and changes go through the open-questions list.

| Spec | Area | Status |
|---|---|---|
| `specs/00-overview.md` | Index and record of decisions | ready |
| `specs/10-map-and-terrain.md` + `data/terrain.yaml` | Maps, terrain, movement, water, line of sight | ready |
| `specs/20-units-and-progression.md` + `data/units.yaml` | Unit stats, capabilities, XP, skill trees | ready |
| `specs/30-special-units-and-victory.md` | Relics, capture, push, victory | ready |
| `specs/40-newcomers-and-social.md` | Newcomer placement, wars, communication, sections | ready |
| `specs/50-hq.md` | HQ, manager, storage | ready |
| `specs/60-economy.md` | Money: earning, spending, transfers | ready |
| `specs/70-combat-and-ap.md` + `data/combat.yaml` | AP, weapons, hits, damage, morale, prisoners | ready |
| `specs/90-research-topic-priority.md` | Research note (input, not a decision) | reference |

## How we work

### Phase 1: specification
1. Decisions come from Q&A with the game designer and are recorded in the matching spec file and in `specs/00-overview.md` (numbered decisions).
2. Every open question gets an ID in `specs/95-open-questions.md` and is ticked when decided, with the number of the decision that settles it.
3. When an area has no blocking open question left, its status goes to **review**, then **ready** once the designer agrees.
4. Each rule in a *ready* spec has a short ID so code and tests can reference it. Prefixes: `MAP` (10), `UNIT` (20), `RELIC` (30), `SOC` (40), `HQ` (50), `ECO` (60), `COMBAT` (70).
   - IDs are **stable**: never renumber. A new rule takes the next free number of its spec; a removed rule keeps its ID, struck through with the decision that removed it.
   - A rule change is a new decision in `specs/00-overview.md`; the rule text is updated in place and keeps its ID.

### Phase 2: implementation with coding agents
1. Work is tracked as GitHub issues grouped in milestones. Each issue names the spec rules it implements and its acceptance criteria.
2. First milestone: a headless rules core (AP, movement cost, combat resolution) that loads `data/*.yaml` and is covered by unit tests. No rendering, no network. Issues: `milestones/m1-rules-core.md`.
3. Then: server-side persistence and networking, then the client.
4. `AGENTS.md` (and `CLAUDE.md`, which points to it) at the repository root tells agents where the specs are, the "numbers only in YAML" rule and how to run the tests.
