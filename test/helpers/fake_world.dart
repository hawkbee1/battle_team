import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/playtest/world/battle_space.dart';
import 'package:battle_team/playtest/world/playtest_world.dart';
import 'package:vector_math/vector_math.dart';

/// A world without a GPU: it draws each unit where the battle puts it.
class FakeWorld implements PlaytestWorld {
  new(MapData map) : surface = TerrainSurface(map);

  @override
  final TerrainSurface surface;

  @override
  final drawn = <String, Vector3>{};

  /// The selected unit last shown.
  String? selected;

  /// The seconds it moved on by.
  double seconds = 0;

  @override
  void show({
    required Iterable<UnitView> units,
    required Iterable<HqView> hqs,
    required Iterable<RelicView> relics,
    required String? selected,
    required Duration? battleTime,
  }) {
    this.selected = selected;
    drawn
      ..clear()
      ..addAll({
        for (final unit in units)
          if (unit.position case final position?)
            unit.unitId: worldOf(position)
              ..y = surface.heightAt(position.x, position.y),
      });
  }

  @override
  void tick(double seconds) => this.seconds += seconds;
}
