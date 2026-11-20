import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// {@template glide}
/// A unit drawn gliding along a route between two clock times (decision
/// 236: the host puts it where it goes from the start of its move, and the
/// drawing shows it getting there), at an even speed along the route's
/// points, facing the way of the stretch it is on.
/// {@endtemplate}
class Glide {
  /// {@macro glide}
  new(Vector3 at) : _points = [at.clone()], _along = const [0];

  List<Vector3> _points;

  // The distance from the first point to each point, in the ground's plane.
  List<double> _along;
  double _start = 0;
  double _end = 0;
  double _yaw = 0;

  /// Where the glide ends.
  Vector3 get to => _points.last.clone();

  /// Glides from where it is at [now] through the points of [route] after
  /// its first (which is where it stands), to arrive in [seconds].
  void retarget(
    List<Vector3> route, {
    required double now,
    required double seconds,
  }) {
    _yaw = yawAt(now);
    _points = [at(now), for (final point in route.skip(1)) point.clone()];
    var length = 0.0;
    _along = [
      0,
      for (var i = 1; i < _points.length; i++)
        length += _flat(_points[i] - _points[i - 1]),
    ];
    _start = now;
    _end = now + seconds;
  }

  /// Where the unit is at [now]: on the route, as far along it as the time
  /// gone; at its end once arrived.
  Vector3 at(double now) {
    final (index, t) = _stretchAt(now);
    if (index < 0) return _points.last.clone();
    return _points[index] + (_points[index + 1] - _points[index]) * t;
  }

  /// The yaw the unit faces at [now]: the way of its stretch of the route
  /// (0 north, a quarter turn east); once arrived, or on a stretch too
  /// short to tell, the way it last faced.
  double yawAt(double now) {
    final (index, _) = _stretchAt(now);
    if (index < 0) {
      for (var i = _points.length - 1; i > 0; i--) {
        if (_flat(_points[i] - _points[i - 1]) > 0.05) {
          return _yaw = _heading(_points[i - 1], _points[i]);
        }
      }
      return _yaw;
    }
    final stretch = _points[index + 1] - _points[index];
    if (_flat(stretch) <= 0.05) return _yaw;
    return _yaw = _heading(_points[index], _points[index + 1]);
  }

  /// The stretch the unit is on at [now], from point `index` to the next,
  /// and how far along it (0 to 1); index -1 once arrived.
  (int, double) _stretchAt(double now) {
    final total = _along.last;
    if (now >= _end || _end <= _start || total <= 0) return (-1, 1);
    final travelled = math.max(0, (now - _start) / (_end - _start)) * total;
    var i = 0;
    while (i + 2 < _points.length && travelled > _along[i + 1]) {
      i++;
    }
    final length = _along[i + 1] - _along[i];
    // Only a first stretch straight up or down is flat-free: it is past.
    return (i, length > 0 ? (travelled - _along[i]) / length : 1);
  }

  static double _flat(Vector3 v) => math.sqrt(v.x * v.x + v.z * v.z);

  static double _heading(Vector3 from, Vector3 to) =>
      math.atan2(to.x - from.x, to.z - from.z);
}
