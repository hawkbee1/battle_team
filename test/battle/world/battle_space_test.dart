import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MapData map;
  late TerrainSurface surface;

  setUpAll(() async {
    map = await loadMapAsset(rootBundle, 'saint_lo_1km');
    surface = TerrainSurface(map);
  });

  group('worldOf', () {
    test('puts east on +X, up on +Y and north on +Z', () {
      expect(worldOf(const Position(1000, 2000, 300)), Vector3(10, 3, -20));
      expect(positionOf(Vector3(10, 3, -20)), const Position(1000, 2000, 300));
    });
  });

  group('directionOf', () {
    test(
      'COMBAT-14 turns a look in the world into a direction of the battle',
      () {
        // East stays east, north is toward smaller y, up stays up.
        expect(directionOf(Vector3(1, 0, 0)), Direction.of(1, 0, 0));
        expect(directionOf(Vector3(0, 0, 1)), Direction.of(0, -1, 0));
        expect(directionOf(Vector3(0, 1, 0)), Direction.of(0, 0, 1));
      },
    );

    test(
      'COMBAT-14 is the direction between two positions, as the world sees it',
      () {
        const from = Position(1000, 2000, 300);
        const to = Position(1000, 1000, 300);
        final look = worldOf(to) - worldOf(from);

        final aim = directionOf(look.normalized());

        expect(aim.x, closeTo(0, 1e-6));
        expect(aim.y, closeTo(-1, 1e-6));
        expect(aim.z, closeTo(0, 1e-6));
      },
    );
  });

  group('fanOut', () {
    test('spreads units on one spot around it, and leaves the others', () {
      final placed = {
        'b': Vector3(0, 0, 0),
        'a': Vector3(0.5, 0, 0),
        'c': Vector3(50, 0, 0),
      };

      final drawn = fanOut(placed);

      expect(drawn['c'], Vector3(50, 0, 0));
      expect((drawn['a']! - drawn['b']!).length, closeTo(14.5, 1e-5));
      expect(drawn['a']!.x, closeTo(7.5, 1e-5));
    });
  });

  group(TerrainSurface, () {
    test('has the size of the 1 km map', () {
      expect(surface.widthM, 1000);
      expect(surface.depthM, 1000);
    });

    test('gives the height of a cell at its centre, and between cells', () {
      final h0 = map.heights[0].toDouble();
      final h1 = map.heights[1].toDouble();
      expect(surface.heightAt(5, 5), h0);
      expect(surface.heightAt(10, 5), closeTo((h0 + h1) / 2, 1e-9));
      // Beyond the map, the nearest edge's.
      expect(surface.heightAt(-50, -50), h0);
    });

    test('finds where a ray from above meets the ground', () {
      final hit = surface.hit(Vector3(505, 500, -55), Vector3(0, -1, 0))!;

      expect(hit.x, closeTo(505, 1e-6));
      expect(hit.y, closeTo(surface.heightAt(505, 55), 0.5));
    });

    test('finds nothing off the map or looking up', () {
      expect(surface.hit(Vector3(505, 500, -55), Vector3(0, 1, 0)), isNull);
      expect(
        surface.hit(Vector3(-200, 500, -55), Vector3(-0.1, -1, 0)),
        isNull,
      );
    });
  });

  group('terrainArrays', () {
    test('has a coloured vertex per cell and two triangles per square', () {
      final arrays = terrainArrays(map);

      expect(arrays.positions.length, 100 * 100 * 3);
      expect(arrays.colors.length, 100 * 100 * 4);
      expect(arrays.indices.length, 99 * 99 * 6);
      expect(arrays.positions.sublist(0, 3), [5, map.heights[0], -5]);
      expect(arrays.colors[3], 1);
    });

    test('draws an unknown terrain grey', () {
      final spec = MapSpec.parse('''
version: 1
name: test
cell_size_m: 10
tile_size: 256
width: 2
depth: 2
terrain_index: [lava]
teams:
  2: [[0, 0], [1, 1]]
relics: []
''');
      final flat = MapData(
        spec: spec,
        width: 2,
        depth: 2,
        heights: Uint16List(4),
        terrain: Uint8List(4),
        features: const MapFeatures(),
      );

      final colors = terrainArrays(flat).colors;

      expect(colors[0], closeTo(colors[1], 1e-9));
      expect(colors[0], closeTo(colors[2], 1e-9));
    });
  });
}
