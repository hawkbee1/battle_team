import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/world/map_edge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// A map of [width] × [depth] cells of 10 m, of the heights [height].
MapData mapOf(int width, int depth, {required int Function(int, int) height}) =>
    MapData(
      spec: MapSpec.parse('''
version: 1
name: test
cell_size_m: 10
tile_size: 256
width: $width
depth: $depth
terrain_index: [grass]
teams:
  2: [[0, 0], [1, 1]]
relics: []
'''),
      width: width,
      depth: depth,
      heights: Uint16List.fromList([
        for (var y = 0; y < depth; y++)
          for (var x = 0; x < width; x++) height(x, y),
      ]),
      terrain: Uint8List(width * depth),
      features: const MapFeatures(),
    );

Vector3 vertex(CliffArrays side, int v) => Vector3(
  side.positions[v * 3],
  side.positions[v * 3 + 1],
  side.positions[v * 3 + 2],
);

void main() {
  group('edgeCliffArrays', () {
    // 4 × 3 cells of 10 m; the height is 10 m per column plus the row.
    late MapData map;
    late List<CliffArrays> sides;

    setUp(() {
      map = mapOf(4, 3, height: (x, y) => 10 * x + y + 20);
      sides = edgeCliffArrays(map);
    });

    test('has a side to the north, south, west and east, five vertices for '
        'each cell along it', () {
      expect(sides, hasLength(4));
      expect(sides.map((side) => side.positions.length ~/ 3), [
        4 * 5,
        4 * 5,
        3 * 5,
        3 * 5,
      ]);
      // Two quads up the wall and one on the high ground, six triangles,
      // between two points along the edge.
      expect(sides.map((side) => side.indices.length ~/ 3), [18, 18, 12, 12]);
    });

    test("stands on the ground's edge, through the centres of the edge "
        'cells', () {
      final north = sides[0];
      final east = sides[3];

      // The north side's foot, along the first row of cells.
      expect(vertex(north, 0), Vector3(5, 20, -5));
      expect(vertex(north, 3 * 5), Vector3(35, 50, -5));
      // The east side's foot, at the last column, down the rows.
      expect(vertex(east, 0), Vector3(35, 50, -5));
      expect(vertex(east, 2 * 5), Vector3(35, 52, -25));
    });

    test('climbs 150 m from the ground, rock then earth, to high ground', () {
      final south = sides[1];

      // The cell (0, 2) is 22 m high.
      expect([for (var row = 0; row < 5; row++) vertex(south, row).y], [
        22,
        168,
        172,
        172,
        172,
      ]);
      Matcher colour((double, double, double) c) => equals([
        closeTo(c.$1, 1e-6),
        closeTo(c.$2, 1e-6),
        closeTo(c.$3, 1e-6),
      ]);
      expect(south.colors.sublist(0, 3), colour(cliffFootColor));
      expect(south.colors.sublist(4, 7), colour(cliffRockColor));
      expect(south.colors.sublist(8, 11), colour(cliffEarthColor));
      expect(south.colors.sublist(12, 15), colour(cliffTopColor));
    });

    test('each wall faces into the map and the high ground up, every '
        'triangle wound the way of its normal', () {
      // Walls stand straight: their triangles face their normal exactly.
      for (final side in sides) {
        for (var i = 0; i < side.indices.length; i += 18) {
          for (var t = i; t < i + 12; t += 3) {
            final first = side.indices[t];
            final a = vertex(side, first);
            final b = vertex(side, side.indices[t + 1]);
            final c = vertex(side, side.indices[t + 2]);
            final normal = Vector3(
              side.normals[first * 3],
              side.normals[first * 3 + 1],
              side.normals[first * 3 + 2],
            );
            expect(
              (b - a).cross(c - a).normalized().dot(normal),
              closeTo(1, 1e-6),
            );
          }
        }
      }
      final inwards = [
        Vector3(0, 0, -1),
        Vector3(0, 0, 1),
        Vector3(1, 0, 0),
        Vector3(-1, 0, 0),
      ];
      for (final (s, side) in sides.indexed) {
        expect(side.normals.sublist(0, 3), [
          inwards[s].x,
          inwards[s].y,
          inwards[s].z,
        ]);
        expect(side.normals.sublist(3 * 3, 3 * 3 + 3), [0, 1, 0]);
        for (var i = 0; i < side.indices.length; i += 3) {
          final first = side.indices[i];
          final a = vertex(side, first);
          final b = vertex(side, side.indices[i + 1]);
          final c = vertex(side, side.indices[i + 2]);
          final normal = Vector3(
            side.normals[first * 3],
            side.normals[first * 3 + 1],
            side.normals[first * 3 + 2],
          );
          // The high ground slopes with the edge (45° on this map): wound
          // the way of its normal, not level.
          expect((b - a).cross(c - a).normalized().dot(normal), greaterThan(0.5));
        }
      }
    });

    test('the high ground runs 3 km out, and two sides meet at a corner', () {
      final north = sides[0];
      final south = sides[1];
      final west = sides[2];
      final east = sides[3];

      // Out of the north-west corner, cell (0, 0) 20 m high.
      expect(vertex(north, 4), Vector3(5 - 3000, 170, -5 + 3000));
      expect(vertex(west, 4), Vector3(5 - 3000, 170, -5 + 3000));
      // Straight out of the next cell north.
      expect(vertex(north, 5 + 4), Vector3(15, 180, -5 + 3000));
      // Out of the south-east corner, cell (3, 2) 52 m high.
      expect(vertex(south, 3 * 5 + 4), Vector3(35 + 3000, 202, -25 - 3000));
      expect(vertex(east, 2 * 5 + 4), Vector3(35 + 3000, 202, -25 - 3000));
    });

    test('takes the rise, the earth and the high ground asked', () {
      final side = edgeCliffArrays(map, riseM: 10, lipM: 1, rimM: 100).first;

      expect(vertex(side, 1).y, 29);
      expect(vertex(side, 2).y, 30);
      expect(vertex(side, 4), Vector3(-95, 30, 95));
    });
  });
}
