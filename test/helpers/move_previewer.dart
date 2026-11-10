import 'dart:io';

import 'package:battle_client/battle_client.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' as nav;
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_rules/battle_rules.dart' as rules;

/// A map of 10 m cells where any cell can be reached by a straight path of
/// the cells between, each cell of grass: a planner that needs no map files.
/// `blocked` cells are never reached.
final class StraightPlanner implements PathPlanner {
  new({this.blocked = const {}});

  /// Cells (x, y) no path leads to.
  final Set<(int, int)> blocked;

  @override
  double get cellSizeM => 10;

  @override
  nav.CellRef? cellAt(Position position) {
    final x = (position.x / 10).floor();
    final y = (position.y / 10).floor();
    return x < 0 || y < 0 || x >= 200 || y >= 200 ? null : nav.CellRef(x, y);
  }

  @override
  Position pointOf(nav.CellRef cell, {bool flying = false}) =>
      Position.metres(cell.x * 10 + 5, cell.y * 10 + 5, 0);

  @override
  PlannedPath? find({
    required rules.Mover mover,
    required nav.CellRef from,
    required nav.CellRef to,
  }) {
    if (blocked.contains((to.x, to.y))) return null;
    final cells = [from, if (from != to) to];
    final length = (cells.length - 1) * 10.0;
    return PlannedPath(
      cells: cells,
      samples: [
        rules.PathSample(
          terrainType: 'grass',
          slopeDegrees: 0,
          lengthM: length,
        ),
      ],
      cost: length * mover.apPerM,
    );
  }
}

/// The move preview over [planner], on the plan's own unit types and terrain.
MovePreviewer testMovePreviewer({PathPlanner? planner}) => MovePreviewer(
  planner: planner ?? StraightPlanner(),
  units: rules.UnitsData.parse(File('plan/data/units.yaml').readAsStringSync()),
  terrain: rules.TerrainData.parse(
    File('plan/data/terrain.yaml').readAsStringSync(),
  ),
);
