import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math.dart';

/// {@template battle_camera}
/// Where the battle is seen from. The view owns the cameras and the world
/// draws through the one it is told to use (`BattleWorld.useCamera`): a
/// Strategy (Gang of Four) for the camera mode, so that `TopDownCamera` and
/// `FirstPersonCamera` swap without the renderer or the view's taps and
/// labels knowing which one is active.
///
/// The world is flutter_scene's: left-handed, +Y up, east on +X and north on
/// +Z (see `worldOf`).
/// {@endtemplate}
abstract interface class BattleCamera {
  /// The eye.
  Vector3 get position;

  /// The unit look direction.
  Vector3 get forward;

  /// The vertical field of view, in radians.
  double get fovY;

  /// The nearest distance drawn, in metres.
  double get near;

  /// The unit whose body the eye is inside, which is not drawn; null for a
  /// camera outside every unit.
  String? get insideUnit;
}

/// The projection of any [BattleCamera].
extension BattleCameraProjection on BattleCamera {
  /// The view of this camera for a screen of [size].
  ViewProjection view(Size size) => ViewProjection(
    position: position,
    forward: forward,
    fovY: fovY,
    size: size,
  );
}

/// {@template view_projection}
/// A camera as the renderer sees it, for a screen of [size]: world points
/// to screen positions and back, matching flutter_scene's
/// `PerspectiveCamera` (left-handed, +Y up, the right of the view is
/// `up × forward`).
/// {@endtemplate}
class ViewProjection {
  /// {@macro view_projection}
  new({
    required Vector3 position,
    required Vector3 forward,
    required this.fovY,
    required this.size,
  }) : position = position.clone(),
       forward = forward.normalized() {
    right = Vector3(0, 1, 0).cross(this.forward).normalized();
    up = this.forward.cross(right);
  }

  /// The eye.
  final Vector3 position;

  /// The unit look direction.
  final Vector3 forward;

  /// The vertical field of view, in radians.
  final double fovY;

  /// The screen's size, in logical pixels.
  final Size size;

  /// The unit vector to the right of the view.
  late final Vector3 right;

  /// The unit vector to the top of the view.
  late final Vector3 up;

  double get _tanHalf => math.tan(fovY / 2);

  double get _aspect => size.height == 0 ? 1 : size.width / size.height;

  /// Where [point] is on the screen, or null when it is behind the eye.
  Offset? project(Vector3 point) {
    final offset = point - position;
    final depth = offset.dot(forward);
    if (depth <= 0.1) return null;
    final x = offset.dot(right) / (depth * _tanHalf * _aspect);
    final y = offset.dot(up) / (depth * _tanHalf);
    return Offset((x + 1) / 2 * size.width, (1 - y) / 2 * size.height);
  }

  /// The direction from the eye through the screen position [screen].
  Vector3 directionAt(Offset screen) {
    final x = size.width == 0 ? 0.0 : 2 * screen.dx / size.width - 1;
    final y = size.height == 0 ? 0.0 : 1 - 2 * screen.dy / size.height;
    return (forward + right * (x * _tanHalf * _aspect) + up * (y * _tanHalf))
        .normalized();
  }
}
