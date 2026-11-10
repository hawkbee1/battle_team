import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:vector_math/vector_math.dart';

/// What the view needs of the 3D world: it shows the section's view, moves
/// on with time, and tells where its units are drawn and where the ground
/// is. `SceneBattleWorld` draws it; tests use a fake, having no GPU.
abstract interface class BattleWorld {
  /// The ground.
  TerrainSurface get surface;

  /// Where each unit is drawn now.
  Map<String, Vector3> get drawn;

  /// Shows what the section sees.
  void show({
    required Iterable<UnitView> units,
    required Iterable<HqView> hqs,
    required Iterable<RelicView> relics,
    required String? selected,
    required Duration? battleTime,
  });

  /// Moves on by [seconds].
  void tick(double seconds);
}
