// POC (branch poc/streamed-world): the logic of units drawn as instances,
// kept apart from the GPU code so it is tested.

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// How a unit is drawn.
enum UnitLevel {
  /// Its model, with its textures.
  near,

  /// Its light model, without texture.
  far,
}

/// The level of a unit [distance] metres from the eye: [UnitLevel.near]
/// within [nearM]. A unit keeps the level it has ([now]) until it is past
/// the limit by [margin], so it does not flicker while it stands there.
UnitLevel unitLevelAt(
  double distance, {
  required UnitLevel? now,
  required double nearM,
  double margin = 1.25,
}) => distance <= nearM || (now == .near && distance <= nearM * margin)
    ? .near
    : .far;

/// {@template instance_slots}
/// Which instance of an instanced mesh draws which key. Instances are kept
/// packed: the one removed gives its index to the last, so removing never
/// shifts the others (`InstancedMesh.removeInstanceAt` shifts every instance
/// after the one it removes).
/// {@endtemplate}
class InstanceSlots<K extends Object> {
  final _keys = <K>[];
  final _indices = <K, int>{};

  /// The number of instances.
  int get length => _keys.length;

  /// The index of the instance of [key], or null when it has none.
  int? indexOf(K key) => _indices[key];

  /// The key of the instance at [index].
  K keyAt(int index) => _keys[index];

  /// Gives [key] the next index: add its instance to the mesh.
  int add(K key) {
    assert(!_indices.containsKey(key), 'a key has one instance');
    _keys.add(key);
    return _indices[key] = _keys.length - 1;
  }

  /// Takes [key] out, or returns null when it has no instance. The instance
  /// at `last` moves to `index`: copy it there in the mesh (when they
  /// differ), then remove the mesh's instance at `last`.
  ({int index, int last})? remove(K key) {
    final index = _indices.remove(key);
    if (index == null) return null;
    final last = _keys.length - 1;
    final moved = _keys.removeLast();
    if (index != last) {
      _keys[index] = moved;
      _indices[moved] = index;
    }
    return (index: index, last: last);
  }
}

/// The turn around +Y that points a model's +Z from [from] towards [to], or
/// [otherwise] when they are less than [still] metres apart on the ground: a
/// unit keeps the way it faces when it stops.
double headingYaw(
  Vector3 from,
  Vector3 to, {
  required double otherwise,
  double still = 0.05,
}) {
  final east = to.x - from.x;
  final north = to.z - from.z;
  if (east * east + north * north < still * still) return otherwise;
  return math.atan2(east, north);
}

/// Where the eye at [eye] looking along [forward] meets ground at height
/// [groundY], no further than [maxM] metres ahead on the ground: the middle
/// of what is on screen. An eye that looks level or up gives the point
/// [maxM] ahead.
Vector3 lookedAt(
  Vector3 eye,
  Vector3 forward, {
  required double groundY,
  double maxM = 150,
}) {
  final flat = math.sqrt(forward.x * forward.x + forward.z * forward.z);
  final drop = eye.y - groundY;
  if (forward.y < 0 && drop > 0) {
    final reach = drop / -forward.y;
    if (reach * flat <= maxM) {
      return Vector3(
        eye.x + forward.x * reach,
        groundY,
        eye.z + forward.z * reach,
      );
    }
  }
  if (flat == 0) return Vector3(eye.x, groundY, eye.z);
  return Vector3(
    eye.x + forward.x / flat * maxM,
    groundY,
    eye.z + forward.z / flat * maxM,
  );
}

/// What unit [index] of a crowd is: a tank one time in [tankEvery], a soldier
/// otherwise, and its team (0 to [teams] less one). Teams come in turn, one
/// step further after each [tankEvery] units, so a unit never has its
/// neighbours' team on the grid of `crowdAt` (32 wide for a thousand) and
/// tanks as well as soldiers are of every team.
({bool tank, int team}) crowdUnitAt(
  int index, {
  int teams = 5,
  int tankEvery = 5,
}) => (
  tank: index % tankEvery == tankEvery - 1,
  team: (index + index ~/ tankEvery) % teams,
);

/// Where unit [index] of a crowd of [count] is after [seconds], from the
/// middle of the crowd, and the way it faces. The crowd is a square grid
/// with [spacingM] between units; each unit walks a circle of [circleM]
/// metres at [speed] metres per second around its place in the grid, so
/// every instance moves every frame. With no [speed] or no [circleM] it
/// stands on its place.
({double east, double north, double yaw}) crowdAt(
  int index,
  int count,
  double seconds, {
  double spacingM = 8,
  double circleM = 3,
  double speed = 1.5,
}) {
  final side = math.sqrt(count).ceil();
  final east = (index % side - (side - 1) / 2) * spacingM;
  final north = (index ~/ side - (side - 1) / 2) * spacingM;
  // Each unit starts somewhere else on its circle.
  final phase = index * 2.399963;
  if (circleM <= 0 || speed <= 0) return (east: east, north: north, yaw: phase);
  final angle = phase + seconds * speed / circleM;
  return (
    east: east + circleM * math.cos(angle),
    north: north + circleM * math.sin(angle),
    // The way it walks: the tangent of the circle.
    yaw: math.atan2(-math.sin(angle), math.cos(angle)),
  );
}
