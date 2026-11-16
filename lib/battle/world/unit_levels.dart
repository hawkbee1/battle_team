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
