import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:vector_math/vector_math.dart';

/// A world without a GPU: it draws each unit where the battle puts it.
class FakeWorld implements BattleWorld {
  new(MapData map) : surface = TerrainSurface(map);

  @override
  final TerrainSurface surface;

  @override
  final drawn = <String, Vector3>{};

  /// The selected unit last shown.
  String? selected;

  /// The target last shown.
  String? target;

  /// The battle time last shown, which units glide to their destination by
  /// (decision 236).
  Duration? battleTime;

  /// The seconds it moved on by.
  double seconds = 0;

  @override
  void show({
    required Iterable<UnitView> units,
    required Iterable<HqView> hqs,
    required Iterable<RelicView> relics,
    required String? selected,
    required String? target,
    required Duration? battleTime,
  }) {
    this.selected = selected;
    this.target = target;
    this.battleTime = battleTime;
    drawn
      ..clear()
      ..addAll({
        for (final unit in units)
          if (unit.position case final position?)
            unit.unitId: worldOf(position)
              ..y = surface.heightAt(position.x, position.y),
      });
  }

  /// The camera last given, and every camera given in order.
  BattleCamera? camera;
  final cameras = <BattleCamera>[];

  @override
  void useCamera(BattleCamera camera) {
    this.camera = camera;
    cameras.add(camera);
  }

  /// Every shot effect it was told to draw, in order.
  final shots = <ShotEffect>[];

  @override
  void showShots(Iterable<ShotEffect> effects) => shots.addAll(effects);

  /// The path last shown; null when none.
  List<Position>? path;

  /// Every call of `showPath`, in order.
  final paths = <List<Position>?>[];

  @override
  void showPath(List<Position>? points) {
    path = points;
    paths.add(points);
  }

  /// The fog last shown; null before any.
  FogModel? fog;

  /// Every call of `showFog`, in order.
  final fogs = <FogModel>[];

  @override
  void showFog(FogModel fog) {
    this.fog = fog;
    fogs.add(fog);
  }

  @override
  void tick(double seconds) => this.seconds += seconds;
}
