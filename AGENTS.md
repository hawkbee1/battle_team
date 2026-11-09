# AGENTS.md — Battle Team

Instructions for coding agents (Claude Code, Codex, Copilot...) working in this repository.

## What this is
Battle Team is a 3D, massive (100+ players), persistent, real-time team battle game. This app is a member of the Hawkbee pub workspace (`resolution: workspace` in `pubspec.yaml`), so its code only builds inside a hawkbee checkout (`git clone --recurse-submodules https://github.com/hawkbee1/hawkbee.git`). The plan in `plan/` stands alone and can be worked on in this repository by itself.

The technical stack was chosen in milestone M2 (`plan/stack/`, eight decision records, confirmed by the designer on 2026-11-01). The current app scaffold (Flutter + Flame) is not a stack decision; M7 decides what stays.

## Where the rules are
The game design lives in `plan/`. **Read it before writing game logic.**
- `plan/README.md`: layout, spec status, how we work.
- `plan/specs/*.md`: the rules. Every rule has a stable ID (`MAP-`, `UNIT-`, `RELIC-`, `SOC-`, `HQ-`, `ECO-`, `COMBAT-`, `AI-` + number).
- `plan/specs/00-overview.md`: numbered design decisions (the history of why).
- `plan/specs/95-open-questions.md` and `plan/specs/96-design-risks.md`: what is still open.
- `plan/data/*.yaml`: every number of the game (stats, costs, tables, battle-setting defaults).
- `plan/milestones/*.md`: milestones and their issues. M2 to M5 are done; M6 (networking) comes next.
- `plan/stack/*.md`: technical stack decision records.
- Work sessions, one per milestone issue: hawkbee `docs/battle_team/`.

"decision N" means design decision N in `00-overview.md`; "stack decision N" means `plan/stack/0N-*.md`.

## How to work here
- **The designer decides the rules.** Write a decision into `00-overview.md` or a spec only when the designer stated it. Anything you had to assume goes into `95-open-questions.md` as a question with "Assumed: …".
- **Specs and data never depend on the stack.** No language, framework or backend assumption in `plan/specs` or `plan/data`.
- **Code follows the stack records** (`plan/stack/`). A change of stack is a new record confirmed by the designer, not a code decision.
- **Lean docs.** Agents read `plan/` on every task: delete obsolete text instead of leaving notes about it, avoid duplicate rules, and keep history in `00-overview.md` and git only.
- **Packages are code and live in hawkbee `packages/`**, never in this repository. Each one is its own public repository `hawkbee1/<name>`, added to hawkbee as a git submodule (stack decision 7).
- **No AI attribution**: no `Co-Authored-By` trailer in commits, no "Generated with Claude Code" line in PRs or comments.
- App locales: English and French.
