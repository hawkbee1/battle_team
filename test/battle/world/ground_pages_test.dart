import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/world/ground_pages.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_shading.dart';
import 'package:flutter_test/flutter_test.dart';

/// A map of grass with a road along its row 1 and an unknown terrain at its
/// north-east corner.
MapData _map(int width, int depth) => MapData(
  spec: MapSpec.parse('''
version: 1
name: test
cell_size_m: 10
tile_size: 256
width: $width
depth: $depth
terrain_index: [grass, road, lava]
teams:
  2: [[0, 0], [1, 1]]
relics: []
'''),
  width: width,
  depth: depth,
  heights: Uint16List(width * depth),
  terrain: Uint8List(width * depth)
    ..fillRange(width, 2 * width, 1)
    ..[width - 1] = 2,
  features: const MapFeatures(),
);

void main() {
  const page = (x0: 2, y0: 1, x1: 5, y1: 3);

  test('a page has a texel a cell, its last column and row included', () {
    expect(pageWidth(page), 4);
    expect(pageHeight(page), 3);
    // A root of `saint_lo`: 1,000 cells wide, and its neighbour's first row.
    final grid = GroundGrid(width: 1000, depth: 5000, cellSizeM: 10);
    final root = grid.cellsOf(grid.roots.first);
    expect(pageWidth(root), 1000);
    expect(pageHeight(root), 1025);
  });

  group('terrainPagePixels', () {
    test("holds the colour of each cell's terrain, north-west first", () {
      final pixels = terrainPagePixels(_map(8, 4), page);

      expect(pixels.length, 4 * 3 * 4);
      // Row 1 of the map is the road, the page's first row.
      expect(pixels.sublist(0, 4), [92, 92, 97, 255]);
      expect(pixels.sublist(3 * 4, 4 * 4), [92, 92, 97, 255]);
      // Row 2 is grass.
      expect(pixels.sublist(4 * 4, 5 * 4), [120, 158, 79, 255]);
      expect(pixels.sublist(11 * 4), [120, 158, 79, 255]);
    });

    test('draws a terrain without a colour grey', () {
      final pixels = terrainPagePixels(_map(8, 4), (
        x0: 6,
        y0: 0,
        x1: 7,
        y1: 0,
      ));

      expect(pixels, [120, 158, 79, 255, 128, 128, 128, 255]);
    });
  });

  group('the fog of a page', () {
    FogModel dark() => FogModel.dark(width: 8, depth: 4, cellSizeM: 10);

    test('MAP-33 keeps a lit cell, dims one seen once, darkens the rest', () {
      expect(fogKeepsByte(FogLevel.lit), 255);
      expect(
        fogKeepsByte(FogLevel.seen) / 255,
        closeTo(FogShade.seenKeeps, 0.002),
      );
      expect(
        fogKeepsByte(FogLevel.never) / 255,
        closeTo(FogShade.neverKeeps, 0.002),
      );
    });

    test('is the red byte of each of its cells, north-west first', () {
      // Cells (2, 1) and (5, 3) seen, then only (2, 1) in sight.
      final fog = dark()
          .lighting(lit: [1 * 8 + 2, 3 * 8 + 5])
          .lighting(dimmed: [3 * 8 + 5]);
      final into = Uint8List(100);

      final pixels = fogPagePixels(fog, page, into);

      expect(pixels.length, 4 * 3 * 4);
      // A view of what was written into the buffer, not a copy.
      expect(into.sublist(0, 4 * 3 * 4), pixels);
      expect(into[0], 255);
      final never = fogKeepsByte(FogLevel.never);
      expect(
        [for (var i = 0; i < 12; i++) pixels[i * 4]],
        [255, ...List.filled(10, never), fogKeepsByte(FogLevel.seen)],
      );
    });

    test('changed only when a cell of the page changed', () {
      final before = dark().lighting(lit: [1 * 8 + 2]);

      expect(fogPageChanged(before, before, page), isFalse);
      // A cell lit outside the page: west of it, and north of it.
      expect(
        fogPageChanged(before, before.lighting(lit: [1 * 8 + 1]), page),
        isFalse,
      );
      expect(fogPageChanged(before, before.lighting(lit: [3]), page), isFalse);
      // Its last cell lit, and its first one out of sight.
      expect(
        fogPageChanged(before, before.lighting(lit: [3 * 8 + 5]), page),
        isTrue,
      );
      expect(
        fogPageChanged(before, before.lighting(dimmed: [1 * 8 + 2]), page),
        isTrue,
      );
    });
  });
}
