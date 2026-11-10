import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math.dart';

/// {@template top_down_camera}
/// The playtest's camera: it looks down at a [target] on the ground from
/// [distance] metres, tilted [pitch] radians below the horizon, facing
/// [heading] (0 looks north, a quarter turn east). It pans, zooms and turns,
/// and turns screen positions into rays and world points into screen
/// positions, so that taps and labels agree with what is drawn.
///
/// The world is flutter_scene's: left-handed, +Y up, east on +X and north
/// on +Z (see `worldOf`).
/// {@endtemplate}
class TopDownCamera {
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

  /// The vertical field of view, in radians.
  final double fovY;

  /// The closest it zooms in.
  final double minDistance;

  /// The farthest it zooms out.
  final double maxDistance;

  /// The unit look direction.
  Vector3 get forward => Vector3(
    math.sin(heading) * math.cos(pitch),
    -math.sin(pitch),
    math.cos(heading) * math.cos(pitch),
  );

  /// The eye.
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
