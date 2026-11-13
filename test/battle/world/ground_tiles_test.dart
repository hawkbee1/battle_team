import 'dart:math' as math;
import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_pathfinding/battle_pathfinding.dart' show CellRef;
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_shading.dart';
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
      expect(arrays.colors.length, (inner + rim) * 4);
      expect(arrays.cells.length, inner + rim);
      expect(arrays.indices.length, 64 * 64 * 6 + rim * 6);
      expect(arrays.indices.reduce(math.max), inner + rim - 1);
      // The first vertex is the first cell's centre, at its height.
      expect(arrays.positions.sublist(0, 3), [5, 0, -5]);
      // Cell (3, 2): 3 east, 2 south.
      const v = 2 * 65 + 3;
      expect(arrays.positions.sublist(v * 3, v * 3 + 3), [35, 7, -25]);
      expect(arrays.cells[v], 2 * 100 + 3);
      // The skirt's first vertex hangs a quad below the first vertex.
      expect(arrays.positions.sublist(inner * 3, inner * 3 + 3), [5, -10, -5]);
      expect(
        arrays.colors.sublist(inner * 4, inner * 4 + 4),
        arrays.colors.sublist(0, 4),
      );
    });

    test("a coarser tile skips cells and still ends on the map's edge", () {
      final arrays = groundTileArrays(map, grid, (level: 1, x: 0, y: 0));

      // Cells 0, 2, … 98, then 99.
      const cols = 51;
      expect(arrays.cells.sublist(0, 3), [0, 2, 4]);
      expect(arrays.cells[cols - 1], 99);
      expect(arrays.cells.length, cols * cols + 4 * (cols - 1));
      expect(arrays.positions.sublist((cols - 1) * 3, cols * 3), [995, 99, -5]);
    });

    test('colours a tile as the whole map is coloured', () {
      final whole = terrainArrays(map).colors;
      final arrays = groundTileArrays(map, grid, (level: 0, x: 1, y: 1));

      for (final v in [0, 7, 36 * 36 - 1]) {
        final cell = arrays.cells[v];
        for (var channel = 0; channel < 4; channel++) {
          expect(
            arrays.colors[v * 4 + channel],
            closeTo(whole[cell * 4 + channel], 1e-6),
          );
        }
      }
    });
  });

  group('fogShadedTileColors', () {
    test('MAP-33 keeps a lit cell, dims one seen once, darkens the rest', () {
      final map = mapOf(100, 100);
      final arrays = groundTileArrays(map, GroundGrid.of(map), (
        level: 0,
        x: 0,
        y: 0,
      ));
      final fog = FogModel.dark(
        width: 100,
        depth: 100,
        cellSizeM: 10,
      ).lighting([0, 1]).lighting([0]);

      final shaded = fogShadedTileColors(arrays.colors, arrays.cells, fog);

      final (red, _, _) = FogShade.tint;
      expect(shaded[0], arrays.colors[0]);
      expect(
        shaded[4],
        closeTo(
          arrays.colors[4] * FogShade.seenKeeps +
              red * (1 - FogShade.seenKeeps),
          1e-6,
        ),
      );
      expect(
        shaded[8],
        closeTo(
          arrays.colors[8] * FogShade.neverKeeps +
              red * (1 - FogShade.neverKeeps),
          1e-6,
        ),
      );
      expect(shaded[11], 1);
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

  group('treeLook', () {
    test('is the same for a cell every time, and stays in its cell', () {
      for (final cell in [0, 1, 4999999, 123456]) {
        final look = treeLook(cell);

        expect(treeLook(cell), look);
        expect(look.east.abs(), lessThanOrEqualTo(0.25));
        expect(look.south.abs(), lessThanOrEqualTo(0.25));
        expect(look.yaw, inInclusiveRange(0, 2 * math.pi));
        expect(look.scale, inInclusiveRange(0.8, 1.25));
      }
      expect(treeLook(10), isNot(treeLook(11)));
    });
  });
}
