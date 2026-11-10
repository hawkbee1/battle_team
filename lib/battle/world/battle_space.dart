import 'dart:math' as math;
import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:vector_math/vector_math.dart';

/// Where a battle [position] is in the 3D world.
///
/// flutter_scene is left-handed with +Y up, and a camera looking along +Z
/// has +X on its right. The world puts east on +X, up on +Y and north on +Z,
/// so that a camera looking north sees east on its right. A battle position
/// counts metres east, south and up of the map's north-west corner.
Vector3 worldOf(Position position) =>
    Vector3(position.x, position.z, -position.y);

/// The battle position of the world point [world].
Position positionOf(Vector3 world) =>
    Position.metres(world.x, -world.z, world.y);

/// Where to draw units that stand on the same spot: [placed] by ID, those
/// within [near] metres of each other on a ring of [radius] metres around
/// their middle, in ID order, so that each shows and can be tapped. Only
/// the drawing moves; the battle keeps them where they are.
Map<String, Vector3> fanOut(
  Map<String, Vector3> placed, {
  double near = 1,
  double radius = 7,
}) {
  final groups = <List<String>>[];
  for (final id in placed.keys.toList()..sort()) {
    final at = placed[id]!;
    final group = groups.where(
      (group) => (placed[group.first]! - at).length < near,
    );
    if (group.isEmpty) {
      groups.add([id]);
    } else {
      group.first.add(id);
    }
  }
  return {
    for (final group in groups)
      for (final (index, id) in group.indexed)
        id: group.length == 1
            ? placed[id]!.clone()
            : placed[id]! +
                  Vector3(
                    radius * math.cos(2 * math.pi * index / group.length),
                    0,
                    radius * math.sin(2 * math.pi * index / group.length),
                  ),
  };
}

/// The colour each terrain type is drawn with; grey for any other.
const terrainColors = <String, (double, double, double)>{
  'grass': (0.47, 0.62, 0.31),
  'forest_floor': (0.27, 0.42, 0.22),
  'sand': (0.86, 0.80, 0.58),
  'mud': (0.45, 0.38, 0.28),
  'rock': (0.55, 0.54, 0.52),
  'road': (0.62, 0.58, 0.50),
  'town_street': (0.50, 0.50, 0.52),
  'mountain': (0.48, 0.45, 0.42),
  'river': (0.27, 0.47, 0.75),
  'lake': (0.22, 0.42, 0.70),
};

/// {@template terrain_surface}
/// The ground of a [map]: its height anywhere, from the heights of its
/// cells' centres, and where a ray first meets it.
/// {@endtemplate}
class TerrainSurface {
  /// {@macro terrain_surface}
  new(this.map) : cell = map.spec.cellSizeM;

  /// The map.
  final MapData map;

  /// The side of a cell, in metres.
  final double cell;

  /// The map's width east to west, in metres.
  double get widthM => map.width * cell;

  /// The map's depth north to south, in metres.
  double get depthM => map.depth * cell;

  /// The ground height, in metres, [east] and [south] metres from the map's
  /// north-west corner: between the four nearest cell centres, and the
  /// nearest edge's beyond the map.
  double heightAt(double east, double south) {
    final x = (east / cell - 0.5).clamp(0, map.width - 1).toDouble();
    final y = (south / cell - 0.5).clamp(0, map.depth - 1).toDouble();
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = math.min(x0 + 1, map.width - 1);
    final y1 = math.min(y0 + 1, map.depth - 1);
    final fx = x - x0;
    final fy = y - y0;
    double h(int cx, int cy) => map.heights[cy * map.width + cx].toDouble();
    final north = h(x0, y0) * (1 - fx) + h(x1, y0) * fx;
    final south_ = h(x0, y1) * (1 - fx) + h(x1, y1) * fx;
    return north * (1 - fy) + south_ * fy;
  }

  /// Where the ray from [origin] along [direction] first meets the ground
  /// inside the map, or null when it does not.
  Vector3? hit(Vector3 origin, Vector3 direction) {
    final step = direction.normalized() * (cell / 4);
    final reach = 4 * (widthM + depthM);
    var point = origin.clone();
    var above = point.y - heightAt(point.x, -point.z);
    for (var travelled = 0.0; travelled < reach; travelled += cell / 4) {
      final next = point + step;
      final nextAbove = next.y - heightAt(next.x, -next.z);
      if (above > 0 && nextAbove <= 0) {
        final t = above / (above - nextAbove);
        final ground = point + step * t;
        final inside =
            ground.x >= 0 &&
            ground.x <= widthM &&
            -ground.z >= 0 &&
            -ground.z <= depthM;
        return inside ? ground : null;
      }
      point = next;
      above = nextAbove;
    }
    return null;
  }
}

/// The vertex arrays of a map's ground mesh.
typedef TerrainArrays = ({
  Float32List positions,
  Float32List colors,
  List<int> indices,
});

/// The ground of [map] as one mesh: a vertex at each cell's centre, at its
/// height, coloured by its terrain and shaded by its slope towards a light
/// from the north-west, so the relief shows without lights.
TerrainArrays terrainArrays(MapData map) {
  final surface = TerrainSurface(map);
  final cell = surface.cell;
  final width = map.width;
  final depth = map.depth;
  final positions = Float32List(width * depth * 3);
  final colors = Float32List(width * depth * 4);
  final light = Vector3(-1, 2, 1)..normalize();
  for (var y = 0; y < depth; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      final east = (x + 0.5) * cell;
      final south = (y + 0.5) * cell;
      final height = map.heights[i].toDouble();
      positions
        ..[i * 3] = east
        ..[i * 3 + 1] = height
        ..[i * 3 + 2] = -south;
      // The slope from the neighbours: east and north rises.
      final dEast =
          surface.heightAt(east + cell, south) -
          surface.heightAt(east - cell, south);
      final dNorth =
          surface.heightAt(east, south - cell) -
          surface.heightAt(east, south + cell);
      final normal = Vector3(-dEast, 2 * cell, -dNorth)..normalize();
      final shade = 0.55 + 0.45 * math.max(0, normal.dot(light));
      final name = map.spec.terrainIndex[map.terrain[i]];
      final (r, g, b) = terrainColors[name] ?? (0.5, 0.5, 0.5);
      colors
        ..[i * 4] = r * shade
        ..[i * 4 + 1] = g * shade
        ..[i * 4 + 2] = b * shade
        ..[i * 4 + 3] = 1;
    }
  }
  final indices = <int>[];
  for (var y = 0; y < depth - 1; y++) {
    for (var x = 0; x < width - 1; x++) {
      final a = y * width + x;
      final b = a + 1;
      final c = a + width;
      final d = c + 1;
      indices.addAll([a, c, b, b, c, d]);
    }
  }
  return (positions: positions, colors: colors, indices: indices);
}
