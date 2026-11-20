import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_rules/battle_rules.dart' show Mover;

/// {@template unit_routes}
/// The way a unit seen moving goes, so that it is drawn going round a river
/// by its bridge or along a road rather than straight through: the cheapest
/// path of the move preview's [previewer], which the host searches the same
/// way (stack decision 8). The host sends where a unit goes, not its path
/// (decision 236): this is the drawing's guess, never a rule. It knows the
/// map as built, not what was built or destroyed during the battle.
/// {@endtemplate}
class UnitRoutes {
  /// {@macro unit_routes}
  const new(this.previewer, {this.maxSearchM = 2000});

  /// The move preview, whose planner searches the path.
  final MovePreviewer previewer;

  /// Past this distance between its ends, in metres, a move is drawn
  /// straight: a search across a big map can take a second, too long for
  /// a frame.
  final double maxSearchM;

  /// The points a unit of [unitType] goes through from [from] to [to], both
  /// included: those of the cells of its path in between. Straight, [from]
  /// then [to], for a flying unit, a unit type the app does not know, a
  /// move past [maxSearchM], ends off the map or in one cell, and a move
  /// with no path.
  List<Position> route({
    required String unitType,
    required bool flying,
    required Position from,
    required Position to,
  }) {
    final straight = [from, to];
    final east = to.x - from.x;
    final south = to.y - from.y;
    if (flying || east * east + south * south > maxSearchM * maxSearchM) {
      return straight;
    }
    final type = previewer.units.unitTypes[unitType];
    final planner = previewer.planner;
    final start = planner.cellAt(from);
    final goal = planner.cellAt(to);
    if (type == null || start == null || goal == null || start == goal) {
      return straight;
    }
    final path = planner.find(
      mover: Mover.unit(type),
      from: start,
      to: goal,
    );
    if (path == null) return straight;
    return [
      from,
      for (final cell in path.cells.sublist(1, path.cells.length - 1))
        planner.pointOf(cell),
      to,
    ];
  }
}
