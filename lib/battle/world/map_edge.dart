import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:vector_math/vector_math.dart';

/// The vertex arrays of one side of the cliffs around a map: `positions`,
/// `normals`, `colors` (RGBA) and `indices`.
typedef CliffArrays = ({
  Float32List positions,
  Float32List normals,
  Float32List colors,
  Uint16List indices,
});

/// The colour of the rock at a cliff's foot, in its shade.
const cliffFootColor = (0.30, 0.28, 0.26);

/// The colour of the rock up the cliff.
const cliffRockColor = (0.56, 0.52, 0.46);

/// The colour of the earth at the top of a cliff.
const cliffEarthColor = (0.38, 0.31, 0.24);

/// The colour of the high ground on top of the cliffs.
const cliffTopColor = (0.42, 0.52, 0.30);

/// The vertices of each point along a side: up the wall its foot, under
/// the earth and its top; on the high ground its inner and its outer edge.
const _rows = 5;

/// The cliffs that close [map] on its four sides (north, south, west, east):
/// from the edge of the ground (the line through the centres of the edge
/// cells, where the ground's mesh ends) a wall climbs [riseM] metres, rock
/// lightening from the foot and [lipM] metres of earth at the top, facing
/// into the map; from its top, high ground runs [rimM] metres out, the map
/// set in a valley. Each side is a strip of quads, one per cell along it;
/// the high ground of two sides meets at the corners.
List<CliffArrays> edgeCliffArrays(
  MapData map, {
  double riseM = 150,
  double lipM = 4,
  double rimM = 3000,
}) {
  final cell = map.spec.cellSizeM;
  double height(int x, int y) => map.heightM(y * map.width + x);
  final west = cell / 2;
  final east = (map.width - 0.5) * cell;
  final north = cell / 2;
  final south = (map.depth - 0.5) * cell;
  CliffArrays side(List<(double, double, double)> edge, Vector3 inward) =>
      _side(edge, inward, riseM: riseM, lipM: lipM, rimM: rimM);
  return [
    side([
      for (var x = 0; x < map.width; x++)
        ((x + 0.5) * cell, north, height(x, 0)),
    ], Vector3(0, 0, -1)),
    side([
      for (var x = 0; x < map.width; x++)
        ((x + 0.5) * cell, south, height(x, map.depth - 1)),
    ], Vector3(0, 0, 1)),
    side([
      for (var y = 0; y < map.depth; y++)
        (west, (y + 0.5) * cell, height(0, y)),
    ], Vector3(1, 0, 0)),
    side([
      for (var y = 0; y < map.depth; y++)
        (east, (y + 0.5) * cell, height(map.width - 1, y)),
    ], Vector3(-1, 0, 0)),
  ];
}

/// One side along [edge] (east, south and ground height of each point),
/// its wall facing [inward] and its high ground running the other way. The
/// outer edge of the high ground reaches [rimM] past both ends too, so two
/// sides cover the corner between them.
CliffArrays _side(
  List<(double, double, double)> edge,
  Vector3 inward, {
  required double riseM,
  required double lipM,
  required double rimM,
}) {
  final count = edge.length;
  final positions = Float32List(count * _rows * 3);
  final normals = Float32List(count * _rows * 3);
  final colors = Float32List(count * _rows * 4);
  final up = Vector3(0, 1, 0);
  final (firstEast, firstSouth, _) = edge.first;
  final (lastEast, lastSouth, _) = edge.last;
  final along = Vector3(lastEast - firstEast, 0, firstSouth - lastSouth)
    ..normalize();
  for (final (i, (east, south, ground)) in edge.indexed) {
    final top = ground + riseM;
    final at = Vector3(east, 0, -south);
    final out = at - inward * rimM;
    if (i == 0) out.sub(along * rimM);
    if (i == count - 1) out.add(along * rimM);
    final rows = [
      (Vector3(at.x, ground, at.z), inward, cliffFootColor),
      (Vector3(at.x, top - lipM, at.z), inward, cliffRockColor),
      (Vector3(at.x, top, at.z), inward, cliffEarthColor),
      (Vector3(at.x, top, at.z), up, cliffTopColor),
      (Vector3(out.x, top, out.z), up, cliffTopColor),
    ];
    for (final (row, (point, normal, (red, green, blue))) in rows.indexed) {
      final v = i * _rows + row;
      positions
        ..[v * 3] = point.x
        ..[v * 3 + 1] = point.y
        ..[v * 3 + 2] = point.z;
      normals
        ..[v * 3] = normal.x
        ..[v * 3 + 1] = normal.y
        ..[v * 3 + 2] = normal.z;
      colors
        ..[v * 4] = red
        ..[v * 4 + 1] = green
        ..[v * 4 + 2] = blue
        ..[v * 4 + 3] = 1;
    }
  }
  final indices = <int>[];
  for (var i = 0; i + 1 < count; i++) {
    // Two quads up the wall, one on the high ground.
    for (final (row, facing) in [(0, inward), (1, inward), (3, up)]) {
      final a = i * _rows + row;
      final b = (i + 1) * _rows + row;
      final c = b + 1;
      final d = a + 1;
      // Counter-clockwise seen from where [facing] points.
      final pa = _at(positions, a);
      final winding = (_at(positions, b) - pa)
          .cross(_at(positions, c) - pa)
          .dot(facing);
      indices.addAll(winding >= 0 ? [a, b, c, a, c, d] : [a, c, b, a, d, c]);
    }
  }
  return (
    positions: positions,
    normals: normals,
    colors: colors,
    indices: Uint16List.fromList(indices),
  );
}

Vector3 _at(Float32List positions, int v) =>
    Vector3(positions[v * 3], positions[v * 3 + 1], positions[v * 3 + 2]);
