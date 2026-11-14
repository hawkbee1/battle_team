import 'dart:math' as math;
import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' show CellRef;
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

MapData mapOf(
  int width,
  int depth, {
  int Function(int x, int y)? height,
  List<MapFeature> features = const [],
}) => MapData(
  spec: MapSpec.parse('''
version: 1
name: test
cell_size_m: 10
tile_size: 256
width: $width
depth: $depth
terrain_index: [grass, road]
teams:
  2: [[0, 0], [1, 1]]
relics: []
'''),
  width: width,
  depth: depth,
  heights: Uint16List.fromList([
    for (var y = 0; y < depth; y++)
      for (var x = 0; x < width; x++) height?.call(x, y) ?? 0,
  ]),
  terrain: Uint8List(width * depth),
  features: MapFeatures(features: features),
);

double flat(double east, double south) => 0;

void main() {
  group('GroundGrid', () {
    test('a small map is one root tile', () {
      final grid = GroundGrid(width: 100, depth: 100, cellSizeM: 10);

      expect(grid.rootLevel, 1);
      expect(grid.roots, [(level: 1, x: 0, y: 0)]);
    });

    test('a long map is a row of roots that span its short side', () {
      final grid = GroundGrid(width: 1000, depth: 5000, cellSizeM: 10);

      expect(grid.rootLevel, 4);
      expect(grid.roots, [for (var y = 0; y < 5; y++) (level: 4, x: 0, y: y)]);
    });

    test('a tile has the children that hold ground of the map', () {
      final grid = GroundGrid(width: 100, depth: 100, cellSizeM: 10);

      expect(grid.childrenOf((level: 1, x: 0, y: 0)), [
        (level: 0, x: 0, y: 0),
        (level: 0, x: 1, y: 0),
        (level: 0, x: 0, y: 1),
        (level: 0, x: 1, y: 1),
      ]);
      expect(grid.childrenOf((level: 0, x: 0, y: 0)), isEmpty);
      // 65 columns: the cells past the first tile are one column, a tile.
      final narrow = GroundGrid(width: 66, depth: 65, cellSizeM: 10);
      expect(narrow.childrenOf((level: 1, x: 0, y: 0)), [
        (level: 0, x: 0, y: 0),
        (level: 0, x: 1, y: 0),
      ]);
    });

    test("a tile ends on its neighbour's first cells, or the map's last", () {
      final grid = GroundGrid(width: 100, depth: 100, cellSizeM: 10);

      expect(grid.cellsOf((level: 0, x: 0, y: 0)), (
        x0: 0,
        y0: 0,
        x1: 64,
        y1: 64,
      ));
      expect(grid.cellsOf((level: 0, x: 1, y: 1)), (
        x0: 64,
        y0: 64,
        x1: 99,
        y1: 99,
      ));
    });

    test('a tile is under one root, whose cells are its page', () {
      final grid = GroundGrid(width: 1000, depth: 5000, cellSizeM: 10);

      expect(grid.rootOf((level: 4, x: 0, y: 3)), (level: 4, x: 0, y: 3));
      expect(grid.rootOf((level: 0, x: 15, y: 16)), (level: 4, x: 0, y: 1));
      expect(grid.rootOf((level: 2, x: 3, y: 19)), (level: 4, x: 0, y: 4));
    });

    test('measures from the eye to the nearest ground of a tile', () {
      final grid = GroundGrid(width: 100, depth: 100, cellSizeM: 10);
      final cells = grid.cellsOf((level: 0, x: 0, y: 0));

      // Above the tile: only the height counts.
      expect(grid.distanceTo(cells, Vector3(300, 50, -300), flat), 50);
      // East of it, on the ground: from its east edge (cell 64's centre).
      expect(grid.distanceTo(cells, Vector3(745, 0, -300), flat), 100);
    });
  });

  group('GroundSelector', () {
    final grid = GroundGrid(width: 1000, depth: 5000, cellSizeM: 10);
    final selector = GroundSelector(grid: grid);
    const fov = 45 * degrees2Radians;

    test('asks for the roots first when nothing is live', () {
      final cut = selector.select(
        eye: Vector3(500, 2, -500),
        fovY: fov,
        heightAt: flat,
        isLive: (_) => false,
      );

      expect(cut.render, isEmpty);
      expect(cut.load.take(5).toSet(), grid.roots.toSet());
      expect([
        for (final tile in cut.load) tile.level,
      ], isSortedUsing<int>((a, b) => b - a));
    });

    test('a tile stands in until all its children are live', () {
      final roots = grid.roots.toSet();

      final cut = selector.select(
        eye: Vector3(500, 2, -500),
        fovY: fov,
        heightAt: flat,
        isLive: roots.contains,
      );

      expect(cut.render.toSet(), roots);
    });

    test('is fine near the eye, coarse far away, and covers the map once', () {
      final eye = Vector3(500, 2, -500);

      final cut = selector.select(
        eye: eye,
        fovY: fov,
        heightAt: flat,
        isLive: (_) => true,
      );

      final under = cut.render.singleWhere((tile) {
        final cells = grid.cellsOf(tile);
        return cells.x0 <= 50 &&
            cells.x1 > 50 &&
            cells.y0 <= 50 &&
            cells.y1 > 50;
      });
      expect(under.level, 0);
      final far = cut.render.singleWhere((tile) {
        final cells = grid.cellsOf(tile);
        return cells.x0 <= 50 && cells.x1 > 50 && cells.y1 == 4999;
      });
      expect(far.level, greaterThan(under.level));
      // Every quad of the map, counted in cells, is in one tile exactly.
      var covered = 0;
      for (final tile in cut.render) {
        final cells = grid.cellsOf(tile);
        covered += (cells.x1 - cells.x0) * (cells.y1 - cells.y0);
      }
      expect(covered, 999 * 4999);
      expect(cut.load.toSet(), containsAll(cut.render));
      expect(cut.load.toSet(), containsAll(grid.roots));
    });

    test('a wider view asks for less detail', () {
      int tiles(double fovY) => selector
          .select(
            eye: Vector3(500, 300, -2500),
            fovY: fovY,
            heightAt: flat,
            isLive: (_) => true,
          )
          .render
          .length;

      expect(tiles(90 * degrees2Radians), lessThan(tiles(fov)));
    });
  });

  group('groundTileArrays', () {
    final map = mapOf(100, 100, height: (x, y) => x + 2 * y);
    final grid = GroundGrid.of(map);

    test('has a vertex at each cell of a level 0 tile, and a skirt', () {
      final arrays = groundTileArrays(map, grid, (level: 0, x: 0, y: 0));

      const inner = 65 * 65;
      const rim = 4 * 64;
      expect(arrays.positions.length, (inner + rim) * 3);
      expect(arrays.texCoords.length, (inner + rim) * 2);
      expect(arrays.colors.length, (inner + rim) * 4);
      expect(arrays.indices.length, 64 * 64 * 6 + rim * 6);
      expect(arrays.indices.reduce(math.max), inner + rim - 1);
      // The first vertex is the first cell's centre, at its height.
      expect(arrays.positions.sublist(0, 3), [5, 0, -5]);
      // Cell (3, 2): 3 east, 2 south.
      const v = 2 * 65 + 3;
      expect(arrays.positions.sublist(v * 3, v * 3 + 3), [35, 7, -25]);
      // The skirt's first vertex hangs a quad below the first vertex, with
      // its shade and its place in the textures.
      expect(arrays.positions.sublist(inner * 3, inner * 3 + 3), [5, -10, -5]);
      expect(
        arrays.colors.sublist(inner * 4, inner * 4 + 4),
        arrays.colors.sublist(0, 4),
      );
      expect(
        arrays.texCoords.sublist(inner * 2, inner * 2 + 2),
        arrays.texCoords.sublist(0, 2),
      );
    });

    test("a coarser tile skips cells and still ends on the map's edge", () {
      final arrays = groundTileArrays(map, grid, (level: 1, x: 0, y: 0));

      // Cells 0, 2, … 98, then 99.
      const cols = 51;
      expect(arrays.positions.length, (cols * cols + 4 * (cols - 1)) * 3);
      expect(
        [for (var v = 0; v < 3; v++) arrays.positions[v * 3]],
        [5, 25, 45],
      );
      expect(arrays.positions.sublist((cols - 1) * 3, cols * 3), [995, 99, -5]);
    });

    test("a vertex reads the textures at the centre of its cell's texel", () {
      final arrays = groundTileArrays(map, grid, (level: 0, x: 0, y: 0));

      // The map is one page of 100 × 100 texels. Cell (3, 2).
      const v = 2 * 65 + 3;
      expect(arrays.texCoords[v * 2], closeTo(3.5 / 100, 1e-6));
      expect(arrays.texCoords[v * 2 + 1], closeTo(2.5 / 100, 1e-6));
      // A coarse tile reads the same texel for the same cell.
      final coarse = groundTileArrays(map, grid, (level: 1, x: 0, y: 0));
      const w = 1 * 51 + 2;
      expect(coarse.positions.sublist(w * 3, w * 3 + 3), [45, 8, -25]);
      expect(coarse.texCoords[w * 2], closeTo(4.5 / 100, 1e-6));
      expect(coarse.texCoords[w * 2 + 1], closeTo(2.5 / 100, 1e-6));
    });

    test('a tile under another root reads the page of that root', () {
      // Three roots of 128 cells from north to south.
      final long = mapOf(100, 300);
      final grid = GroundGrid.of(long);
      expect(grid.roots, hasLength(3));

      // Cells 128 to 192 of the map, in the page of cells 128 to 256.
      final arrays = groundTileArrays(long, grid, (level: 0, x: 0, y: 2));

      expect(arrays.positions.sublist(0, 3), [5, 0, -1285]);
      expect(arrays.texCoords[0], closeTo(0.5 / 100, 1e-6));
      expect(arrays.texCoords[1], closeTo(0.5 / 129, 1e-6));
      // The last row of the root above is the first of this one: the same
      // cells, at the same place in the world.
      final above = groundTileArrays(long, grid, (level: 0, x: 0, y: 1));
      const last = 64 * 65;
      expect(above.positions.sublist(last * 3, last * 3 + 3), [5, 0, -1285]);
      expect(above.texCoords[last * 2 + 1], closeTo(128.5 / 129, 1e-6));
    });

    test('shades a tile as the whole map is shaded', () {
      // The whole map's colours are the terrain's (grass everywhere) times
      // the shade; a tile's are the shade alone.
      final whole = terrainArrays(map).colors;
      final (red, green, blue) = terrainColors['grass']!;
      final arrays = groundTileArrays(map, grid, (level: 0, x: 1, y: 1));

      // The tile's cells are 64 to 99 on both axes.
      for (final v in [0, 7, 36 * 36 - 1]) {
        final cell = (64 + v ~/ 36) * 100 + 64 + v % 36;
        for (final (channel, colour) in [red, green, blue].indexed) {
          expect(
            arrays.colors[v * 4 + channel] * colour,
            closeTo(whole[cell * 4 + channel], 1e-6),
          );
        }
        expect(arrays.colors[v * 4 + 3], 1);
      }
    });
  });

  group('objectChunks', () {
    test('groups the trees and buildings by chunk, and nothing else', () {
      final map = mapOf(
        200,
        100,
        features: const [
          MapFeature(
            kind: FeatureKind.object,
            type: 'tree',
            cells: [CellRef(1, 2), CellRef(63, 63), CellRef(64, 2)],
          ),
          MapFeature(
            kind: FeatureKind.object,
            type: 'building',
            cells: [CellRef(130, 70)],
          ),
          MapFeature(
            kind: FeatureKind.object,
            type: 'wall',
            cells: [CellRef(5, 5)],
          ),
        ],
      );

      final chunks = objectChunks(map);

      expect(chunks.keys, [(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 1)]);
      expect(chunks[(x: 0, y: 0)]!.trees, [2 * 200 + 1, 63 * 200 + 63]);
      expect(chunks[(x: 1, y: 0)]!.trees, [2 * 200 + 64]);
      expect(chunks[(x: 2, y: 1)]!.buildings, [70 * 200 + 130]);
      expect(chunks[(x: 2, y: 1)]!.trees, isEmpty);
    });

    test("a chunk covers its own cells, cut at the map's edge", () {
      final grid = GroundGrid(width: 200, depth: 100, cellSizeM: 10);

      expect(chunkCells(grid, (x: 0, y: 0)), (x0: 0, y0: 0, x1: 63, y1: 63));
      expect(chunkCells(grid, (x: 3, y: 1)), (
        x0: 192,
        y0: 64,
        x1: 199,
        y1: 99,
      ));
    });
  });

  group('chunks of another size', () {
    test('objectChunks groups by the cells asked', () {
      final map = mapOf(
        200,
        100,
        features: const [
          MapFeature(
            kind: FeatureKind.object,
            type: 'tree',
            cells: [CellRef(1, 2), CellRef(15, 15), CellRef(16, 2)],
          ),
        ],
      );

      final chunks = objectChunks(map, cells: 16);

      expect(chunks.keys, [(x: 0, y: 0), (x: 1, y: 0)]);
      expect(chunks[(x: 0, y: 0)]!.trees, [2 * 200 + 1, 15 * 200 + 15]);
    });

    test('chunkCells covers the cells asked', () {
      final grid = GroundGrid(width: 200, depth: 100, cellSizeM: 10);

      expect(chunkCells(grid, (x: 1, y: 0), cells: 16), (
        x0: 16,
        y0: 0,
        x1: 31,
        y1: 15,
      ));
      expect(chunkCells(grid, (x: 12, y: 6), cells: 16), (
        x0: 192,
        y0: 96,
        x1: 199,
        y1: 99,
      ));
    });
  });

  group('chunksAround', () {
    final grid = GroundGrid(width: 200, depth: 100, cellSizeM: 10);

    test('gives the chunks of the square around the eye', () {
      // 500 m east, 500 m south: chunks are 160 m wide.
      final chunks = chunksAround(grid, Vector3(500, 50, -500), 100, cells: 16);

      expect(chunks, [
        for (var y = 2; y <= 3; y++)
          for (var x = 2; x <= 3; x++) (x: x, y: y),
      ]);
    });

    test("stops at the map's edge", () {
      final chunks = chunksAround(grid, Vector3(1990, 0, -990), 5000);

      expect(chunks, [
        for (var y = 0; y <= 1; y++)
          for (var x = 0; x <= 3; x++) (x: x, y: y),
      ]);
      expect(chunksAround(grid, Vector3(-9000, 0, 0), 100), isEmpty);
    });

    test('holds every chunk within the range', () {
      final eye = Vector3(733, 20, -411);
      final around = chunksAround(grid, eye, 300, cells: 16).toSet();

      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 13; x++) {
          final id = (x: x, y: y);
          final distance = grid.distanceTo(
            chunkCells(grid, id, cells: 16),
            eye,
            flat,
          );
          if (distance <= 300) expect(around, contains(id));
        }
      }
    });
  });

  group('treeLevelAt', () {
    TreeLevel at(double distance, TreeLevel now) =>
        treeLevelAt(distance, now: now, nearM: 100, rangeM: 1500);

    test('is near within the near range, far within the range', () {
      expect(at(0, TreeLevel.none), TreeLevel.near);
      expect(at(100, TreeLevel.none), TreeLevel.near);
      expect(at(101, TreeLevel.none), TreeLevel.far);
      expect(at(1500, TreeLevel.none), TreeLevel.far);
      expect(at(1501, TreeLevel.none), TreeLevel.none);
    });

    test('a chunk keeps its level until past the limit by the margin', () {
      expect(at(120, TreeLevel.near), TreeLevel.near);
      expect(at(120, TreeLevel.far), TreeLevel.far);
      expect(at(126, TreeLevel.near), TreeLevel.far);
      expect(at(1800, TreeLevel.far), TreeLevel.far);
      expect(at(1800, TreeLevel.near), TreeLevel.far);
      expect(at(1800, TreeLevel.none), TreeLevel.none);
      expect(at(1876, TreeLevel.far), TreeLevel.none);
    });
  });

  group('treeConeArrays', () {
    test('is a cone of one triangle a side, on the origin', () {
      final cone = treeConeArrays();

      expect(cone.indices, hasLength(6 * 3));
      expect(cone.positions, hasLength(12 * 3));
      expect(cone.normals, hasLength(12 * 3));
      for (var v = 0; v < 12; v++) {
        final position = Vector3.array(cone.positions, v * 3);
        final normal = Vector3.array(cone.normals, v * 3);
        if (v < 6) {
          expect(position.y, 0);
          expect(position.length, closeTo(1, 1e-6));
        } else {
          expect(position, Vector3(0, 1, 0));
        }
        expect(normal.length, closeTo(1, 1e-6));
        expect(normal.y, greaterThan(0));
      }
    });

    test('each side joins two neighbours of the base to the apex', () {
      final cone = treeConeArrays(sides: 5);

      for (var side = 0; side < 5; side++) {
        expect(cone.indices.sublist(side * 3, side * 3 + 3), [
          side,
          5 + side,
          (side + 1) % 5,
        ]);
      }
      // The normal of a side points out of it.
      final out = Vector3.array(cone.normals, 5 * 3);
      final middle =
          (Vector3.array(cone.positions) + Vector3.array(cone.positions, 3)) /
          2;
      expect(out.dot(middle), greaterThan(0));
    });
  });

  group('treeLook', () {
    test('is the same for a cell every time, and stays in its cell', () {
      for (final cell in [0, 1, 4999999, 123456]) {
        final look = treeLook(cell);

        expect(treeLook(cell), look);
        expect(look.east.abs(), lessThanOrEqualTo(0.25));
        expect(look.south.abs(), lessThanOrEqualTo(0.25));
        expect(look.yaw, inInclusiveRange(0, 2 * math.pi));
        expect(look.scale, inInclusiveRange(0.8, 1.25));
        expect(look.kind, inInclusiveRange(0, 0.9999));
      }
      expect(treeLook(10), isNot(treeLook(11)));
    });

    test('shares a forest between the kinds of tree', () {
      final first = [
        for (var cell = 0; cell < 5000; cell++)
          if (treeLook(cell).kind < 0.5) cell,
      ];

      expect(first.length, inInclusiveRange(2000, 3000));
      // Not in stripes: neighbours differ often.
      final changes = [
        for (var cell = 1; cell < 5000; cell++)
          if ((treeLook(cell).kind < 0.5) != (treeLook(cell - 1).kind < 0.5))
            cell,
      ];
      expect(changes.length, greaterThan(1000));
    });
  });
}
