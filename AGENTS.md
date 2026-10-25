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

## Rules for agents
1. **Numbers only in YAML.** Never write a game number (HP, AP, price, range, factor, radius, duration...) in Dart code. Load it from `plan/data/*.yaml`. Tests on real values read the same files; test fixtures may contain their own numbers.
2. **Cite rule IDs.** Code that implements a rule names its ID in a comment; each test name starts with the rule ID it checks, e.g. `test('COMBAT-06 moves at regen speed at 0 AP', ...)`.
3. **Do not invent rules.** If a spec is unclear, missing or contradictory, stop and add a question to `plan/specs/95-open-questions.md` instead of guessing. Do not edit `plan/specs/` or `plan/data/` to make code pass; spec changes are design decisions taken by the game designer.
4. **Deterministic rules core.** Game rules take time and a seeded RNG as inputs; no wall clock, no global random, no I/O inside rule functions.
5. **Keep the rules core headless.** `packages/battle_team_rules/` (milestone 1) is pure Dart: no Flutter, no Flame, no network.
6. Follow the existing style: `very_good_analysis` lints, `bloc` for app state (`bloc_lint` rules), immutable models with `equatable`.

## Commands
```sh
# App tests (from the repository root)
flutter test --coverage --test-randomize-ordering-seed random

# Rules core tests (milestone 1)
cd packages/battle_team_rules && dart test

# Lints
dart analyze
dart run bloc_tools:bloc lint .

# Run the app (needs ../../env/<flavor>.json from the Hawkbee workspace)
flutter run --flavor development --target lib/main_development.dart --dart-define-from-file=../../env/development.json
```

## Definition of done for an issue
- Every rule ID listed in the issue has at least one test named after it.
- `dart analyze` is clean and all tests pass.
- No new number in Dart code outside test fixtures.
- New questions raised while coding are in `plan/specs/95-open-questions.md` and linked in the pull request.
