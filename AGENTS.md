# AGENTS.md — Battle Team

Instructions for coding agents (Claude Code, Codex, Copilot...) working in this repository.

## What this is
Battle Team is a 3D, massive (100+ players), persistent, real-time team battle game. Flutter + Flame client, Appwrite backend (shared Hawkbee project). This app is a member of the Hawkbee pub workspace (`resolution: workspace` in `pubspec.yaml`).

## Where the rules are
The game design lives in `plan/`. **Read it before writing game logic.**
- `plan/README.md`: layout, spec status, how we work.
- `plan/specs/*.md`: the rules. Every rule has a stable ID (`MAP-`, `UNIT-`, `RELIC-`, `SOC-`, `HQ-`, `ECO-`, `COMBAT-` + number).
- `plan/specs/00-overview.md`: numbered design decisions (the history of why).
- `plan/data/*.yaml`: every number of the game (stats, costs, tables, battle-setting defaults).
- `plan/milestones/*.md`: the current milestone and its issues.
