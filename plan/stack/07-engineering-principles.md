# Stack decision 7: engineering principles and package layout

Status: **confirmed** (designer, 2026-11-01; milestone M2, Issue 7). Rules: none. This record governs code only; specs and data stay stack-neutral.

## What the stack must support
- One rules core for the host and the client (stack decision 1, M4), changed in one place.
- New unit types, terrains, movement classes and AI behaviours added by data (`plan/data/*.yaml`) and new classes, not by editing existing rule code.
- Several senders of orders (players, AI agents, the server, the Discord bridge) behind one interface (stack decision 3).
- Replaceable adapters for Appwrite, the network library, Discord, the payment provider and Sentry (stack decision 6).
- Rules tested with no network, no storage and no rendering (M4).

## Principles
Applied to Dart:
- **Single responsibility.** A package has one reason to change. `battle_rules` does no I/O. `battle_host` owns sockets and storage. The client owns rendering and input.
- **Open/closed.** A new unit, terrain or movement class is a data row plus a class that implements an existing interface.
- **Liskov substitution.** Every implementation of a port passes the same contract tests. The in-memory and the Appwrite-backed snapshot store run one shared suite.
- **Interface segregation.** Small ports, each used by few clients: `Clock`, `SeededRandom`, `CommandSink`, `SnapshotStore`, `LogSink`, `ErrorReporter` (Sentry, stack decision 6). A class depends only on the ports it calls.
- **Dependency inversion.** Rules depend on ports. Hosts inject the implementations through constructors, and the app wires them with `RepositoryProvider` (layered-architecture skill).
- **Sealed types for variants.** Commands, events and unit states are sealed classes matched with an exhaustive `switch`. The compiler then lists every case left unhandled when a variant is added.
- **No global mutable state.** Singletons are not used in rules or host code: they break determinism (stack decision 1) and test isolation.

## Patterns (Gang of Four)
A pattern is used where a rule or a decision named here needs it. Otherwise a plain class.

| Pattern | Used for | Reason |
|---|---|---|
| Command | Every order: a typed object with sender, time and arguments | Logged, replayed from the log, and sent over the socket (stack decisions 2, 3) |
| Strategy | Movement-class costs (MAP-11 to MAP-19), pathfinding cost, AI behaviours (AI-*) | New behaviour without editing callers |
| State | Unit states: on the field, carried or stored; flying or landed; observing; capturing or pushing | Each state owns the actions it allows |
| Memento | Battle snapshot every 5 minutes (stack decision 2) | Restore without exposing internals |
| Observer | Events from the rules to the presentation and to the log | Rules do not know their listeners |
| Adapter | Appwrite, the network library, Discord, the payment provider, Sentry, the Appwrite Function entry points | External APIs stay at the edge of the code |
| Facade | The battle host's command API, used by players, AI, the server and the bridge | One entry point for all senders |
| Chain of Responsibility | Order checks: sender, right to act, rules, AP | Each check separate and testable |
| Decorator | Origin tagging and logging around the command handler (decisions 162, 166) | Adds the origin without changing the handler |
| Flyweight | Map and unit/terrain definitions loaded once | One map copy serves all its battles (stack decision 1) |
| Factory Method | The tile loader: host data on the server, meshes on the client (MAP-05) | One loader, two outputs |

Not used: Singleton (see above) and Visitor (sealed types cover it in Dart).

## Tooling
- Analysis, formatting and tests run through the VGV tools where they are installed: the Dart MCP tools (`analyze_files`, `dart_format`), the Very Good CLI MCP tools (`test`, `packages_check_licenses`), and the `green-gate` skill for the quality loop. In the hawkbee dev container a VGV plugin hook blocks `flutter test` and `dart test` in Bash, so tests run through the MCP `test` tool there.
- Package APIs are checked with the context7 MCP before use.
- Each milestone's PR gets the VGV review agents: architecture, test quality and simplicity (`vgv-wingspan`).

## Package layout
- Every Battle Team package is code, so it lives in the hawkbee workspace `packages/` folder, beside the other packages. None lives under `apps/battle_team/`. The rules (`plan/specs`, `plan/data`, `plan/milestones`, `plan/stack`) are written documents and stay in `apps/battle_team/plan/`.
- Each package is its own public GitHub repository, `hawkbee1/<name>`, added to hawkbee as a git submodule at `packages/<name>`. This is the repo-per-package rule of the whole workspace. Creation procedure (scaffold, `gh repo create --public`, `git submodule add`, merge commits only): hawkbee `docs/dart_code_3d/agent-workflow.md`, section 2.
- Planned packages, each created in the milestone that first needs it, from a Very Good CLI template:

| Package | Milestone | Template |
|---|---|---|
| `battle_pathfinding` (paths) | M3 | `dart_package` |
| `battle_rules` (rules core) | M4 | `dart_package` |
| `battle_protocol` (commands and messages between host and client) | M5, M6 | `dart_package` |
| `battle_map` (map loader and builder, stack decision 5; M3 uses its own test fixture format) | M5 | `dart_package` |
| `battle_stats` (statistics and medals from logs, stack decision 8) | M5 | `dart_package` |
| `battle_client` (the client side of a battle connection, for the app and Dart AI agents) | M6 | `dart_package` |
| `battle_host` (simulation host, native executable) | M5 | `dart_cli` |
| `battle_discord_bridge` (Discord bridge, stack decision 6, native executable) | M7 | `dart_cli` |

- `apps/battle_team` depends on them by version, not by relative path (convention of hawkbee commit d7a6716).
- **Game data in packages.** Packages build only inside a hawkbee checkout (`resolution: workspace`), so tests on real values read `apps/battle_team/plan/data/*.yaml` from that checkout, by a path relative to the package (designer, 2026-11-01). The data is never copied into a package. `battle_rules` reads no files: its caller passes the YAML text. The app bundles `plan/data` as assets; the host reads it from disk.

## Consequences
- A package that an Appwrite Function runs needs a committed vendored copy, as `hawkbee_schema` has in `backend/functions/ping/vendor/`, because the Appwrite CLI honours `.gitignore` when it packages a function.
- Each package passes the four gates (analyze, format, test, coverage) before its PR.
- Patterns in the code are named in the doc comment of the class that uses them, so a reviewer can check them against this record.
