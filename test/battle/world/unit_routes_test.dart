import 'package:battle_client/battle_client.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' as nav;
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_rules/battle_rules.dart' as rules;
import 'package:battle_team/battle/world/unit_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/move_previewer.dart';

/// A planner that goes round by a bridge: from any cell, through the cell
/// (5, 9), then to the goal. On the cells of [StraightPlanner].
final class _DetourPlanner implements PathPlanner {
  new({this.blocked = const {}});

  final Set<(int, int)> blocked;
  final _cells = StraightPlanner();
  final asked = <rules.Mover>[];

  @override
  double get cellSizeM => _cells.cellSizeM;

  @override
  nav.CellRef? cellAt(Position position) => _cells.cellAt(position);

  @override
  Position pointOf(nav.CellRef cell, {bool flying = false}) =>
      _cells.pointOf(cell, flying: flying);

  @override
  PlannedPath? find({
    required rules.Mover mover,
    required nav.CellRef from,
    required nav.CellRef to,
  }) {
    asked.add(mover);
    if (blocked.contains((to.x, to.y))) return null;
    return PlannedPath(
      cells: [from, const nav.CellRef(5, 9), to],
      samples: const [],
      cost: 0,
    );
  }
}

void main() {
  group('UnitRoutes', () {
    late _DetourPlanner planner;
    late UnitRoutes routes;

    setUp(() {
      planner = _DetourPlanner(blocked: {(30, 30)});
      routes = UnitRoutes(testMovePreviewer(planner: planner));
    });

    List<Position> route({
      required (double, double) from,
      required (double, double) to,
      String unitType = 'soldier',
      bool flying = false,
    }) => routes.route(
      unitType: unitType,
      flying: flying,
      from: Position.metres(from.$1, from.$2, 0),
      to: Position.metres(to.$1, to.$2, 0),
    );

    test("goes through the points of its path's cells, from where it is to "
        'where it goes', () {
      expect(route(from: (12, 13), to: (98, 7)), [
        Position.metres(12, 13, 0),
        Position.metres(55, 95, 0),
        Position.metres(98, 7, 0),
      ]);
      expect(planner.asked.single.modes, isNot(contains('flying')));
    });

    test('is straight for a flying unit, an unknown unit type, a move in '
        'one cell or off the map, or with no path', () {
      final straight = [Position.metres(12, 13, 0), Position.metres(98, 7, 0)];

      expect(route(flying: true, from: (12, 13), to: (98, 7)), straight);
      expect(route(unitType: 'dragon', from: (12, 13), to: (98, 7)), straight);
      expect(route(from: (12, 13), to: (14, 15)), [
        Position.metres(12, 13, 0),
        Position.metres(14, 15, 0),
      ]);
      expect(route(from: (12, 13), to: (-5, 7)), [
        Position.metres(12, 13, 0),
        Position.metres(-5, 7, 0),
      ]);
      expect(route(from: (12, 13), to: (305, 305)), [
        Position.metres(12, 13, 0),
        Position.metres(305, 305, 0),
      ]);
      expect(planner.asked, hasLength(1));
    });

    test('is straight past the farthest it searches', () {
      final near = UnitRoutes(
        testMovePreviewer(planner: planner),
        maxSearchM: 50,
      );

      expect(
        near.route(
          unitType: 'soldier',
          flying: false,
          from: Position.metres(0, 0, 0),
          to: Position.metres(60, 0, 0),
        ),
        hasLength(2),
      );
      expect(planner.asked, isEmpty);
    });
  });
}
