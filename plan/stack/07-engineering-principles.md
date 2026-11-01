# Stack decision 7: engineering principles and package layout

Status: **proposed** (milestone M2, Issue 7). Rules: none. This record governs code only; specs and data stay stack-neutral.

## What the stack must support
- One rules core for the host and the client (decision 1, M4), changed in one place.
- New unit types, terrains, movement classes and AI behaviours added by data (`plan/data/*.yaml`) and new classes, not by editing existing rule code.
- Several senders of orders (players, AI agents, the server, the Discord bridge) behind one interface (decision 3).
- Replaceable adapters for Appwrite, the network library, Discord, store billing and the payment provider (decision 6).
- Rules tested with no network, no storage and no rendering (M4).

## Principles
Applied to Dart:
- **Single responsibility.** A package has one reason to change. `battle_rules` does no I/O. `battle_host` owns sockets and storage. The client owns rendering and input.
- **Open/closed.** A new unit, terrain or movement class is a data row plus a class that implements an existing interface.
- **Liskov substitution.** Every implementation of a port passes the same contract tests. The in-memory and the Appwrite-backed snapshot store run one shared suite.
- **Interface segregation.** Small ports, each used by few clients: `Clock`, `SeededRandom`, `CommandSink`, `SnapshotStore`, `LogSink`. A class depends only on the ports it calls.
- **Dependency inversion.** Rules depend on ports. Hosts inject the implementations through constructors, and the app wires them with `RepositoryProvider` (layered-architecture skill).
- **Sealed types for variants.** Commands, events and unit states are sealed classes matched with an exhaustive `switch`. The compiler then lists every case left unhandled when a variant is added.
- **No global mutable state.** Singletons are not used in rules or host code: they break determinism (decision 1) and test isolation.

## Patterns (Gang of Four)
A pattern is used where a rule or a decision named here needs it. Otherwise a plain class.

| Pattern | Used for | Reason |
|---|---|---|
| Command | Every order: a typed object with sender, time and arguments | Logged, replayed from the log, and sent over the socket (decisions 2, 3) |
| Strategy | Movement-class costs (MAP-11 to MAP-19), pathfinding cost, AI behaviours (AI-*) | New behaviour without editing callers |
| State | Unit activity states named in `specs/20` and `specs/70` | Each state owns the transitions it allows |
| Memento | Battle snapshot every 5 minutes (decision 2) | Restore without exposing internals |
| Observer | Events from the rules to the presentation and to the log | Rules do not know their listeners |
| Adapter | Appwrite, the network library, Discord, store and payment APIs, the Appwrite Function entry points | External APIs stay at the edge of the code |
| Facade | The battle host's command API, used by players, AI, the server and the bridge | One entry point for all senders |
| Chain of Responsibility | Order checks: sender, right to act, rules, cooldowns | Each check separate and testable |
| Decorator | Origin tagging and logging around the command handler (decision 162) | Adds the origin without changing the handler |
| Flyweight | Map and unit/terrain definitions loaded once | The shared map of decision 1 is held once for all battles |
| Factory Method | The tile loader: host data on the server, meshes on the client (MAP-05) | One loader, two outputs |

Not used: Singleton (see above) and Visitor (sealed types cover it in Dart).

## Tooling
- Analysis, formatting and tests run through the VGV tools: the Dart MCP tools (`analyze_files`, `dart_format`), the Very Good CLI MCP tools (`test`, `packages_check_licenses`), and the `green-gate` skill for the quality loop. The hooks block `flutter test` and `dart test` in Bash, so these tools are the way to run tests.
- Package APIs are checked with the context7 MCP before use.
- Each milestone's PR gets the VGV review agents: architecture, test quality and simplicity (`vgv-wingspan`).

## Package layout
- Every Battle Team package lives in the Hawkbee workspace `packages/` folder, beside the other packages. None lives under `apps/battle_team/`.
- Planned names: `battle_rules` (rules core, M4), `battle_pathfinding` (M3), `battle_protocol` (commands and messages between host and client, M5 and M6), `battle_host` (simulation host, a Dart executable, M5), `battle_map` (map format loader and builder, decision 5), `battle_stats` (statistics and medals from logs, decision 8).
- `apps/battle_team` depends on them by version, not by relative path (convention of commit d7a6716).
- **Open:** whether each Battle Team package is its own repository added as a submodule, as the other packages are. To be confirmed by the designer.

## Consequences
- A package that an Appwrite Function runs needs a committed vendored copy, as `hawkbee_schema` already has, because the Appwrite CLI honours `.gitignore` when it packages a function.
- Each package passes the four gates (analyze, format, test, coverage) before its PR.
- Patterns in the code are named in the doc comment of the class that uses them, so a reviewer can check them against this record.
