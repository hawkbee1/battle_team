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

/// How a building looks: the colours of its `roof` and of its `walls`.
typedef BuildingLook = ({
  (double, double, double) roof,
  (double, double, double) walls,
});

/// The looks buildings take in turn: slate and tiled roofs over walls of
/// stone, render, concrete and brick, as in the towns of Normandy.
const buildingLooks = <BuildingLook>[
  (roof: (0.30, 0.32, 0.37), walls: (0.72, 0.62, 0.52)),
  (roof: (0.42, 0.24, 0.20), walls: (0.82, 0.78, 0.70)),
  (roof: (0.30, 0.32, 0.37), walls: (0.62, 0.60, 0.56)),
  (roof: (0.52, 0.30, 0.22), walls: (0.72, 0.62, 0.52)),
  (roof: (0.36, 0.36, 0.38), walls: (0.82, 0.78, 0.70)),
  (roof: (0.42, 0.24, 0.20), walls: (0.66, 0.50, 0.40)),
];

/// How a bridge's deck looks: a road on stone.
const BuildingLook bridgeLook = (
  roof: (0.36, 0.36, 0.38),
  walls: (0.60, 0.56, 0.50),
);

/// How thick a bridge's deck is, in metres.
const bridgeSlabM = 1.2;

/// The top of a building: the height of its flat `roof` in the 3D world
/// and its `look`.
typedef BuildingTop = ({double roof, BuildingLook look});

/// How tall a building of [cells] cells is, in metres: a house of one or
/// two cells 5 to 8 m, a block 8, 11 or 14 m (three to five storeys),
/// picked from [seed] so the same building always gets the same.
double buildingHeightM(int cells, int seed) =>
    cells <= 2 ? 5.0 + seed % 4 : 8.0 + seed % 3 * 3;

/// A number of its own for the building whose first cell is ([x], [y]).
int buildingSeed(int x, int y) =>
    ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF;

/// The top of every building of [buildings] (each the cells it stands on,
/// first its north-west one) by cell (`y × width + x`): one roof for all its
/// cells, [buildingHeightM] above the highest ground at their centres
/// ([heightAt]), and one of [buildingLooks]. Cells of the same building
/// share the same record.
Map<int, BuildingTop> buildingTops({
  required Iterable<List<(int, int)>> buildings,
  required int width,
  required double cellSizeM,
  required HeightAt heightAt,
}) {
  final tops = <int, BuildingTop>{};
  for (final cells in buildings) {
    if (cells.isEmpty) continue;
    final ground = cells
        .map(
          (cell) => heightAt(
            (cell.$1 + 0.5) * cellSizeM,
            (cell.$2 + 0.5) * cellSizeM,
          ),
        )
        .reduce(math.max);
    final seed = buildingSeed(cells.first.$1, cells.first.$2);
    final top = (
      roof: ground + buildingHeightM(cells.length, seed),
      look: buildingLooks[seed % buildingLooks.length],
    );
    for (final (x, y) in cells) {
      tops[y * width + x] = top;
    }
  }
  return tops;
}

/// The most vertices a building cell takes: a roof and four walls of four
/// vertices each; a slab has an underside of four more.
const _cellVertices = 20;

/// The buildings on [cells] (`y × width + x`) as meshes of [maxVertices]
/// vertices at most, so each fits 16-bit indices.
///
/// A cell is a block that fills it, under the flat roof of its building
/// ([topAt], asked for any column and row, those of other chunks and those
/// off the map too, null where no building stands), with a wall on each
/// side where its building is higher than what stands next door. Cells of
/// the same building, or of buildings of the same height, are merged: no
/// wall between them; between two buildings, the step from the higher roof
/// down to the lower one. An outer wall goes [sinkM] metres under the
/// lowest ground along its side, so no slope shows a gap under it.
///
/// With [slabM], a cell is a slab that thick instead, a bridge's deck: its
/// outer sides go down [slabM] only, and it has an underside.
List<BuildingArrays> buildingArrays({
  required List<int> cells,
  required int width,
  required double cellSizeM,
  required HeightAt heightAt,
  required BuildingTop? Function(int x, int y) topAt,
  double sinkM = 0.5,
  double? slabM,
  int maxVertices = 24000,
}) {
  final meshes = <BuildingArrays>[];
  var batch = _Batch();

  for (final cell in cells) {
    final x = cell % width;
    final y = cell ~/ width;
    final top = topAt(x, y);
    if (top == null) continue;
    if (batch.vertices + _cellVertices + (slabM == null ? 0 : 4) >
        maxVertices) {
      meshes.add(batch.arrays());
      batch = _Batch();
    }
    final west = x * cellSizeM;
    final east = west + cellSizeM;
    final north = y * cellSizeM;
    final south = north + cellSizeM;
    final roof = top.roof;
    batch.quad(
      Vector3(west, roof, -north),
      Vector3(east, roof, -north),
      Vector3(east, roof, -south),
      Vector3(west, roof, -south),
      Vector3(0, 1, 0),
      top.look.roof,
    );
    if (slabM != null) {
      final under = roof - slabM;
      batch.quad(
        Vector3(west, under, -north),
        Vector3(west, under, -south),
        Vector3(east, under, -south),
        Vector3(east, under, -north),
        Vector3(0, -1, 0),
        top.look.walls,
      );
    }

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
      if (topAt(nx, ny) case final next?) {
        bottom = next.roof;
        if (bottom >= roof - 0.01) return;
      } else if (slabM != null) {
        bottom = roof - slabM;
      } else {
        bottom = math.min(heightAt(a.$1, a.$2), heightAt(b.$1, b.$2)) - sinkM;
      }
      batch.quad(
        Vector3(a.$1, roof, -a.$2),
        Vector3(b.$1, roof, -b.$2),
        Vector3(b.$1, bottom, -b.$2),
        Vector3(a.$1, bottom, -a.$2),
        out,
        top.look.walls,
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
