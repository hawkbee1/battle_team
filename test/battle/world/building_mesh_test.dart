import 'package:battle_team/battle/world/building_mesh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const width = 10;

int at(int x, int y) => y * width + x;

/// Each of [cells] a building of its own, its roof 6 m above the ground at
/// its centre, in the first look.
List<BuildingArrays> build(
  List<int> cells, {
  double Function(double east, double south)? heightAt,
  double? slabM,
  int maxVertices = 24000,
}) {
  final ground = heightAt ?? (east, south) => 0;
  return buildingArrays(
    cells: cells,
    width: width,
    cellSizeM: 10,
    heightAt: ground,
    topAt: (x, y) => x >= 0 && x < width && y >= 0 && cells.contains(at(x, y))
        ? (roof: ground(x * 10 + 5, y * 10 + 5) + 6, look: buildingLooks.first)
        : null,
    slabM: slabM,
    maxVertices: maxVertices,
  );
}

Vector3 vertex(BuildingArrays mesh, int index) => Vector3(
  mesh.positions[index * 3],
  mesh.positions[index * 3 + 1],
  mesh.positions[index * 3 + 2],
);

/// The quads of [mesh] whose vertices have [normal].
int quadsFacing(BuildingArrays mesh, Vector3 normal) {
  var count = 0;
  for (var v = 0; v < mesh.normals.length ~/ 3; v += 4) {
    if (mesh.normals[v * 3] == normal.x &&
        mesh.normals[v * 3 + 1] == normal.y &&
        mesh.normals[v * 3 + 2] == normal.z) {
      count++;
    }
  }
  return count;
}

void main() {
  group('buildingArrays', () {
    test('no building, no mesh', () {
      expect(build([]), isEmpty);
    });

    test('a building alone is a roof and four walls that fill its cell', () {
      final mesh = build([at(2, 3)]).single;

      expect(mesh.positions, hasLength(20 * 3));
      expect(mesh.normals, hasLength(20 * 3));
      expect(mesh.colors, hasLength(20 * 4));
      expect(mesh.indices, hasLength(10 * 3));
      final xs = [for (var v = 0; v < 20; v++) vertex(mesh, v).x];
      final ys = [for (var v = 0; v < 20; v++) vertex(mesh, v).y];
      final zs = [for (var v = 0; v < 20; v++) vertex(mesh, v).z];
      expect(xs.reduce((a, b) => a < b ? a : b), 20);
      expect(xs.reduce((a, b) => a > b ? a : b), 30);
      expect(zs.reduce((a, b) => a < b ? a : b), -40);
      expect(zs.reduce((a, b) => a > b ? a : b), -30);
      // The roof 6 m up, the walls half a metre into the ground.
      expect(ys.reduce((a, b) => a > b ? a : b), 6);
      expect(ys.reduce((a, b) => a < b ? a : b), -0.5);
    });

    test('every triangle faces the way its normal says', () {
      final mesh = build([at(2, 3), at(3, 3), at(3, 4)]).single;

      for (var i = 0; i < mesh.indices.length; i += 3) {
        final a = vertex(mesh, mesh.indices[i]);
        final b = vertex(mesh, mesh.indices[i + 1]);
        final c = vertex(mesh, mesh.indices[i + 2]);
        final normal = Vector3(
          mesh.normals[mesh.indices[i] * 3],
          mesh.normals[mesh.indices[i] * 3 + 1],
          mesh.normals[mesh.indices[i] * 3 + 2],
        );
        expect((b - a).cross(c - a).normalized().dot(normal), closeTo(1, 1e-6));
      }
    });

    test('the roof and the walls have their colours', () {
      final mesh = build([at(0, 0)]).single;

      expect(mesh.colors.sublist(0, 4), [
        closeTo(buildingLooks.first.roof.$1, 1e-6),
        closeTo(buildingLooks.first.roof.$2, 1e-6),
        closeTo(buildingLooks.first.roof.$3, 1e-6),
        1,
      ]);
      expect(mesh.colors.sublist(16, 20), [
        closeTo(buildingLooks.first.walls.$1, 1e-6),
        closeTo(buildingLooks.first.walls.$2, 1e-6),
        closeTo(buildingLooks.first.walls.$3, 1e-6),
        1,
      ]);
    });

    test('two buildings side by side have no wall between them', () {
      final mesh = build([at(2, 3), at(3, 3)]).single;

      expect(quadsFacing(mesh, Vector3(0, 1, 0)), 2);
      expect(quadsFacing(mesh, Vector3(1, 0, 0)), 1);
      expect(quadsFacing(mesh, Vector3(-1, 0, 0)), 1);
      expect(quadsFacing(mesh, Vector3(0, 0, 1)), 2);
      expect(quadsFacing(mesh, Vector3(0, 0, -1)), 2);
    });

    test('a block of buildings has walls around it only', () {
      final mesh = build([
        for (var y = 0; y < 3; y++)
          for (var x = 0; x < 3; x++) at(x, y),
      ]).single;

      // 9 roofs and 12 walls.
      expect(mesh.indices, hasLength((9 + 12) * 6));
    });

    test('on a slope the higher roof has a wall down to the lower one', () {
      // The ground rises 1 m every 10 m to the east.
      final mesh = build([
        at(2, 3),
        at(3, 3),
      ], heightAt: (east, south) => east / 10).single;

      // The west wall of the lower building and of the higher one.
      expect(quadsFacing(mesh, Vector3(-1, 0, 0)), 2);
      expect(quadsFacing(mesh, Vector3(1, 0, 0)), 1);
      // The step: the last quad facing west, from 9.5 m down to 8.5 m.
      final ys = <double>{};
      for (var v = 0; v < mesh.normals.length ~/ 3; v++) {
        if (mesh.normals[v * 3] == -1 && vertex(mesh, v).x == 30) {
          ys.add(vertex(mesh, v).y);
        }
      }
      expect(ys, {9.5, 8.5});
    });

    test('an outer wall goes under the lowest ground along its side', () {
      final mesh = build([
        at(2, 3),
      ], heightAt: (east, south) => east / 10).single;

      double lowest(double x) => [
        for (var v = 0; v < 20; v++)
          if (vertex(mesh, v).x == x) vertex(mesh, v).y,
      ].reduce((a, b) => a < b ? a : b);
      // The ground is at 2 m on the west side and at 3 m on the east.
      expect(lowest(20), 1.5);
      expect(lowest(30), 1.5);
      final east = [
        for (var v = 0; v < 20; v++)
          if (mesh.normals[v * 3] == 1) vertex(mesh, v).y,
      ];
      expect(east.reduce((a, b) => a < b ? a : b), 2.5);
    });

    test('a building at the edge of the map has all its walls', () {
      final mesh = build([at(0, 0)]).single;

      expect(mesh.indices, hasLength(10 * 3));
    });

    test('between two buildings of different heights, a wall steps down '
        'from the higher roof to the lower one', () {
      final mesh = buildingArrays(
        cells: [at(2, 3), at(3, 3)],
        width: width,
        cellSizeM: 10,
        heightAt: (east, south) => 0,
        topAt: (x, y) => switch ((x, y)) {
          (2, 3) => (roof: 14.0, look: buildingLooks[0]),
          (3, 3) => (roof: 8.0, look: buildingLooks[1]),
          _ => null,
        },
      ).single;

      final steps = <double>{
        for (var v = 0; v < mesh.normals.length ~/ 3; v++)
          if (mesh.normals[v * 3] == 1 && vertex(mesh, v).x == 30)
            vertex(mesh, v).y,
      };
      expect(steps, {14, 8});
      // The step is a wall of the higher building.
      for (var v = 0; v < mesh.normals.length ~/ 3; v++) {
        if (mesh.normals[v * 3] == 1 && vertex(mesh, v).x == 30) {
          expect(mesh.colors[v * 4], closeTo(buildingLooks[0].walls.$1, 1e-6));
        }
      }
    });

    test('a slab, a bridge deck, is that thick, with an underside', () {
      final mesh = build([at(2, 3), at(3, 3)], slabM: 1.5).single;

      expect(quadsFacing(mesh, Vector3(0, -1, 0)), 2);
      final ys = {
        for (var v = 0; v < mesh.positions.length ~/ 3; v++) vertex(mesh, v).y,
      };
      expect(ys, {6, 4.5});
    });

    test('a cell no building stands on draws nothing', () {
      final mesh = buildingArrays(
        cells: [at(2, 3), at(5, 5)],
        width: width,
        cellSizeM: 10,
        heightAt: (east, south) => 0,
        topAt: (x, y) =>
            (x, y) == (2, 3) ? (roof: 6.0, look: buildingLooks[0]) : null,
      ).single;

      expect(mesh.positions, hasLength(20 * 3));
    });

    test('buildings past the most vertices go to another mesh', () {
      // Apart from one another: 20 vertices each.
      final meshes = build([
        for (var x = 0; x < 10; x += 2) at(x, 0),
      ], maxVertices: 40);

      expect(meshes, hasLength(3));
      expect(meshes.map((mesh) => mesh.positions.length ~/ 3), [40, 40, 20]);
      for (final mesh in meshes) {
        expect(
          mesh.indices.every((index) => index < mesh.positions.length ~/ 3),
          isTrue,
        );
      }
    });
  });

  group('buildingTops', () {
    test('a building has one flat roof over all its cells, its height above '
        'the highest ground at their centres, and one look', () {
      final tops = buildingTops(
        buildings: [
          [(2, 3), (3, 3), (2, 4)],
          [(7, 7)],
        ],
        width: width,
        cellSizeM: 10,
        // The ground rises 1 m every 10 m to the east.
        heightAt: (east, south) => east / 10,
      );

      expect(tops.keys, {at(2, 3), at(3, 3), at(2, 4), at(7, 7)});
      final block = tops[at(2, 3)]!;
      expect(tops[at(3, 3)], same(block));
      expect(tops[at(2, 4)], same(block));
      final seed = buildingSeed(2, 3);
      expect(block.roof, 3.5 + buildingHeightM(3, seed));
      expect(block.look, buildingLooks[seed % buildingLooks.length]);
      expect(
        tops[at(7, 7)]!.roof,
        7.5 + buildingHeightM(1, buildingSeed(7, 7)),
      );
    });

    test('a building without cells has no top', () {
      expect(
        buildingTops(
          buildings: [[]],
          width: width,
          cellSizeM: 10,
          heightAt: (east, south) => 0,
        ),
        isEmpty,
      );
    });

    test('a house is 5 to 8 m tall, a block of three cells or more 8, 11 or '
        '14 m', () {
      final houses = {
        for (var seed = 0; seed < 20; seed++) buildingHeightM(1, seed),
      };
      expect(houses, {5, 6, 7, 8});
      expect(buildingHeightM(2, 3), 8);
      final blocks = {
        for (var seed = 0; seed < 20; seed++) buildingHeightM(16, seed),
      };
      expect(blocks, {8, 11, 14});
    });

    test('the same building always gets the same seed', () {
      expect(buildingSeed(499, 1830), buildingSeed(499, 1830));
      expect(buildingSeed(499, 1830), isNot(buildingSeed(1830, 499)));
      expect(buildingSeed(999, 4999), greaterThanOrEqualTo(0));
    });
  });
}
