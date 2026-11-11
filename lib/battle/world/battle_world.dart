import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:vector_math/vector_math.dart';

/// What the view needs of the 3D world: it shows the section's view, moves
/// on with time, and tells where its units are drawn and where the ground
/// is. A Strategy for swappable renderers (Gang of Four): `SceneBattleWorld`
/// draws it with flutter_scene, tests use a fake, having no GPU, and a
/// renderer chosen after the benchmarks of M7 Issue 13 replaces it without
/// touching the view.
abstract interface class BattleWorld {
  /// The ground.
  TerrainSurface get surface;

  /// Where each unit is drawn now.
  Map<String, Vector3> get drawn;

  /// Shows what the section sees, with the [selected] unit and the [target]
  /// it would fire at marked.
  void show({
    required Iterable<UnitView> units,
    required Iterable<HqView> hqs,
    required Iterable<RelicView> relics,
    required String? selected,
    required String? target,
    required Duration? battleTime,
  });

  /// Draws from [camera] from now on: the body of the unit the eye is
  /// inside (`BattleCamera.insideUnit`) is not drawn. It changes how the
  /// world is seen, never what it shows: the same units are drawn from
  /// either camera (decision 237).
  void useCamera(BattleCamera camera);

  /// Draws [effects], the shots the section sees, for a moment each (Observer:
  /// the view hands the world what the cubit announces). Nothing is kept
  /// beyond their short lives; an effect holds only what the section may see
  /// (decisions 234 and 237).
  void showShots(Iterable<ShotEffect> effects);

  /// Draws the move the player is previewing as a line through [points] on
  /// the ground (M7 Issue 8), until it is called again; null or none clears
  /// it. Only the path of the section's own unit: nothing the section does
  /// not see (decision 237).
  void showPath(List<Position>? points);

  /// Shades the ground by what the section sees (M7 Issue 9, MAP-27, MAP-33):
  /// in sight now as it is, seen once dimmed, never seen dark, until it is
  /// called again. Called when the fog changes, not every frame (stack
  /// decision 4); the model holds nothing of any unit the section does not see
  /// (decision 237).
  void showFog(FogModel fog);

  /// Moves on by [seconds].
  void tick(double seconds);
}
