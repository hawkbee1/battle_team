import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:vector_math/vector_math.dart';

/// {@template top_down_camera}
/// The playtest's camera: it looks down at a [target] on the ground from
/// [distance] metres, tilted [pitch] radians below the horizon, facing
/// [heading] (0 looks north, a quarter turn east). It pans, zooms and turns,
/// and turns screen positions into rays and world points into screen
/// positions, so that taps and labels agree with what is drawn.
///
/// It is the camera mode of the overview, one of the two `BattleCamera`s.
/// {@endtemplate}
class TopDownCamera implements BattleCamera {
  /// {@macro top_down_camera}
  new({
    required Vector3 target,
    this.distance = 400,
    this.heading = 0,
    this.pitch = 55 * degrees2Radians,
    this.fovY = 45 * degrees2Radians,
    this.minDistance = 30,
    this.maxDistance = 3000,
  }) : target = target.clone();

  /// The ground point it looks at.
  Vector3 target;

  /// How far the eye is from the [target], in metres.
  double distance;

  /// Where it faces, in radians: 0 is north, a quarter turn east.
  double heading;

  /// How far below the horizon it looks, in radians.
  double pitch;

  @override
  final double fovY;

  /// The closest it zooms in.
  final double minDistance;

  /// The farthest it zooms out.
  final double maxDistance;

  @override
  Vector3 get forward => Vector3(
    math.sin(heading) * math.cos(pitch),
    -math.sin(pitch),
    math.cos(heading) * math.cos(pitch),
  );

  @override
  Vector3 get position => target - forward * distance;

  /// The ground direction to the right of the view.
  Vector3 get right => Vector3(math.cos(heading), 0, -math.sin(heading));

  /// The ground direction to the top of the view.
  Vector3 get ahead => Vector3(math.sin(heading), 0, math.cos(heading));

  /// Moves the target by [delta] screen pixels in a view of [size], the
  /// ground following the finger.
  void pan(Offset delta, Size size) {
    final metresPerPixel =
        2 * distance * math.tan(fovY / 2) / math.max(size.height, 1);
    target
      ..sub(right * (delta.dx * metresPerPixel))
      ..add(ahead * (delta.dy * metresPerPixel));
  }

  /// Zooms by [factor]: above 1 comes closer.
  void zoom(double factor) {
    distance = (distance / factor).clamp(minDistance, maxDistance);
  }

  /// Turns by [radians], clockwise seen from above.
  void turn(double radians) => heading += radians;

  @override
  double get near => 1;

  @override
  String? get insideUnit => null;
}
