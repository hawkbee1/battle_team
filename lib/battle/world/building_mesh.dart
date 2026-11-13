// POC (branch poc/streamed-world): the buildings of a chunk as a few meshes
// made in code instead of an instanced box per cell. Batching by a count of
// vertices follows dashmap (https://github.com/bdero/dashmap, MIT, Copyright
// (c) 2026 Brandon DeRosier), which batches 24,000 vertices per mesh.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:vector_math/vector_math.dart';

/// The vertex arrays of a mesh of buildings: `positions` in the 3D world,
/// `normals`, `colors` (RGBA, the roofs in one colour and the walls in
/// another) and `indices`.
typedef BuildingArrays = ({
  Float32List positions,
  Float32List normals,
  Float32List colors,
  Uint16List indices,
});

/// The colour of a building's walls.
const buildingWallColor = (0.72, 0.62, 0.52);

/// The colour of a building's roof.
const buildingRoofColor = (0.42, 0.24, 0.20);

/// The most vertices a building cell takes: a roof and four walls of four
/// vertices each.
const _cellVertices = 20;

/// The buildings on [cells] (`y × width + x`) as meshes of [maxVertices]
/// vertices at most, so each fits 16-bit indices.
///
/// A cell is a block that fills it: a flat roof [wallM] metres above the
/// ground at its centre ([heightAt]), and a wall on each side where no
/// building stands ([isBuilding], asked for any column and row, those of
/// other chunks and those off the map too). Blocks side by side are merged:
/// no wall between them, but the step from the higher roof down to the
/// lower one on a slope. An outer wall goes [sinkM] metres under the lowest
/// ground along its side, so no slope shows a gap under it.
List<BuildingArrays> buildingArrays({
  required List<int> cells,
  required int width,
  required double cellSizeM,
  required HeightAt heightAt,
  required bool Function(int x, int y) isBuilding,
  double wallM = 6,
  double sinkM = 0.5,
  int maxVertices = 24000,
}) {
  final meshes = <BuildingArrays>[];
  var batch = _Batch();

  double roofOf(int x, int y) =>
      heightAt((x + 0.5) * cellSizeM, (y + 0.5) * cellSizeM) + wallM;

  for (final cell in cells) {
    if (batch.vertices + _cellVertices > maxVertices) {
      meshes.add(batch.arrays());
      batch = _Batch();
    }
    final x = cell % width;
    final y = cell ~/ width;
    final west = x * cellSizeM;
    final east = west + cellSizeM;
    final north = y * cellSizeM;
    final south = north + cellSizeM;
    final roof = roofOf(x, y);
    batch.quad(
      Vector3(west, roof, -north),
      Vector3(east, roof, -north),
      Vector3(east, roof, -south),
      Vector3(west, roof, -south),
      Vector3(0, 1, 0),
      buildingRoofColor,
    );

    // A side: the neighbour across it, its two ends (east, south) and the
    // way it faces.
    void side(
      int nx,
      int ny,
      (double, double) a,
      (double, double) b,
      Vector3 out,
    ) {
      final double bottom;
      if (isBuilding(nx, ny)) {
        bottom = roofOf(nx, ny);
        if (bottom >= roof - 0.01) return;
      } else {
        bottom =
            math.min(
              roof - wallM,
              math.min(heightAt(a.$1, a.$2), heightAt(b.$1, b.$2)),
            ) -
            sinkM;
      }
      batch.quad(
        Vector3(a.$1, roof, -a.$2),
        Vector3(b.$1, roof, -b.$2),
        Vector3(b.$1, bottom, -b.$2),
        Vector3(a.$1, bottom, -a.$2),
        out,
        buildingWallColor,
      );
    }

    side(x, y - 1, (west, north), (east, north), Vector3(0, 0, 1));
    side(x, y + 1, (west, south), (east, south), Vector3(0, 0, -1));
    side(x - 1, y, (west, north), (west, south), Vector3(-1, 0, 0));
    side(x + 1, y, (east, north), (east, south), Vector3(1, 0, 0));
  }
  if (batch.vertices > 0) meshes.add(batch.arrays());
  return meshes;
}

/// The vertices of a mesh being made.
class _Batch {
  final _positions = <double>[];
  final _normals = <double>[];
  final _colors = <double>[];
  final _indices = <int>[];

  int get vertices => _positions.length ~/ 3;

  /// Adds the quad [a], [b], [c], [d] (its corners in a loop), wound
  /// counter-clockwise seen from where [normal] points.
  void quad(
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Vector3 d,
    Vector3 normal,
    (double, double, double) color,
  ) {
    final first = vertices;
    for (final corner in [a, b, c, d]) {
      _positions.addAll([corner.x, corner.y, corner.z]);
      _normals.addAll([normal.x, normal.y, normal.z]);
      _colors.addAll([color.$1, color.$2, color.$3, 1]);
    }
    final outwards = (b - a).cross(c - a).dot(normal) > 0;
    _indices.addAll(
      outwards
          ? [first, first + 1, first + 2, first, first + 2, first + 3]
          : [first, first + 2, first + 1, first, first + 3, first + 2],
    );
  }

  BuildingArrays arrays() => (
    positions: Float32List.fromList(_positions),
    normals: Float32List.fromList(_normals),
    colors: Float32List.fromList(_colors),
    indices: Uint16List.fromList(_indices),
  );
}
