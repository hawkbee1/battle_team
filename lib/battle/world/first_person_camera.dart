import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:vector_math/vector_math.dart';

/// How the first-person view looks: display constants, not game numbers
/// (those are in `plan/data`).
abstract final class FirstPersonLook {
  /// The vertical field of view, in radians.
  static const double fovY = 70 * degrees2Radians;

  /// The nearest distance drawn, in metres: the unit's own body is not drawn,
  /// so the eye can come close to what it looks at.
  static const near = 0.3;

  /// How far up or down the eye looks at most, in radians, short of straight
  /// up or down where "up" has no direction.
  static const double maxPitch = 85 * degrees2Radians;

  /// What a dragged pixel turns the view by, in radians.
  static const radiansPerPixel = 0.005;
}

/// {@template first_person_camera}
/// The camera of a unit's eyes (decision 5): [eyeHeightM] above the ground
/// where the unit stands, which is the top of its hit volume
/// (`hit_box_m.height`, decision 235), looking along [yaw] and [pitch]. The
/// other `BattleCamera` of the Strategy is the `TopDownCamera`.
///
/// The view is rebuilt from the two angles each time it is read, never
/// composed from the last one, so that turning does not drift.
/// {@endtemplate}
class FirstPersonCamera implements BattleCamera {
  /// {@macro first_person_camera}
  ///
  /// [feet] is where the unit stands; [yaw] 0 looks north, a quarter turn
  /// east; [pitch] is above the horizon when positive.
  new({
    required this.unitId,
    required this.eyeHeightM,
    required Vector3 feet,
    double yaw = 0,
    double pitch = 0,
  }) : feet = feet.clone(),
       _yaw = _wrapped(yaw),
       _pitch = pitch.clamp(
         -FirstPersonLook.maxPitch,
         FirstPersonLook.maxPitch,
       );

  /// The unit whose eyes these are.
  final String unitId;

  /// The eye's height above the ground, in metres.
  final double eyeHeightM;

  /// Where the unit stands.
  Vector3 feet;

  double _yaw;
  double _pitch;

  /// Where the view faces, in radians: 0 is north, a quarter turn east.
  double get yaw => _yaw;

  /// How far above the horizon the view looks, in radians.
  double get pitch => _pitch;

  /// Moves the camera to where the unit now stands.
  void standAt(Vector3 point) => feet.setFrom(point);

  /// Turns the view by a drag of [delta] pixels: right turns to the east, up
  /// looks up.
  void look(Offset delta) {
    _yaw = _wrapped(_yaw + delta.dx * FirstPersonLook.radiansPerPixel);
    _pitch = (_pitch - delta.dy * FirstPersonLook.radiansPerPixel).clamp(
      -FirstPersonLook.maxPitch,
      FirstPersonLook.maxPitch,
    );
  }

  /// Turns the view by [radians], clockwise seen from above.
  void turn(double radians) => _yaw = _wrapped(_yaw + radians);

  @override
  Vector3 get position => feet + Vector3(0, eyeHeightM, 0);

  @override
  Vector3 get forward => Vector3(
    math.sin(_yaw) * math.cos(_pitch),
    math.sin(_pitch),
    math.cos(_yaw) * math.cos(_pitch),
  );

  @override
  double get fovY => FirstPersonLook.fovY;

  @override
  double get near => FirstPersonLook.near;

  @override
  String? get insideUnit => unitId;

  static double _wrapped(double radians) => radians % (2 * math.pi);
}
