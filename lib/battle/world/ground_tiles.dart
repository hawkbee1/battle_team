// POC (branch poc/streamed-world): the ground as a quadtree of tiles instead
// of one mesh, so a 10 × 50 km map draws. The quadtree cut ([GroundSelector])
// and the skirt are adapted from dashmap (https://github.com/bdero/dashmap,
// MIT, Copyright (c) 2026 Brandon DeRosier): `tile_selector.dart` and
// `heightfield_mesh.dart`.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:vector_math/vector_math.dart';

/// The quads along the side of a ground tile, at every level: a tile's mesh
/// holds at most 65 × 65 vertices and its skirt, within 16-bit indices.
const groundTileQuads = 64;

/// A tile of the ground's quadtree. At `level` 0 it has a vertex at each
/// cell and spans [groundTileQuads] cells; each level above doubles the
/// cells between two vertices and the span.
typedef GroundTile = ({int level, int x, int y});

/// The cells a tile or a chunk covers: the first and the last on each axis.
typedef CellRect = ({int x0, int y0, int x1, int y1});

/// The ground height [east] and [south] metres from the map's north-west
/// corner.
typedef HeightAt = double Function(double east, double south);

/// {@template ground_grid}
/// How a map of [width] × [depth] cells is cut into [GroundTile]s.
/// {@endtemplate}
class GroundGrid {
  /// {@macro ground_grid}
  new({required this.width, required this.depth, required this.cellSizeM});

  /// The grid of [map].
  factory of(MapData map) => GroundGrid(
    width: map.width,
    depth: map.depth,
    cellSizeM: map.spec.cellSizeM,
  );

  /// The columns of the map.
  final int width;

  /// The rows of the map.
  final int depth;

  /// The side of a cell, in metres.
  final double cellSizeM;

  /// The cells between two vertices of a tile of [level].
  int stepOf(int level) => 1 << level;

  /// The cells along the side of a tile of [level].
  int spanOf(int level) => groundTileQuads << level;

  /// The level of the coarsest tiles: the first whose tiles span the map's
  /// short side, so a long map is a row of roots.
  late final int rootLevel = () {
    final shortest = math.max(1, math.min(width, depth) - 1);
    var level = 0;
    while (spanOf(level) < shortest) {
      level++;
    }
    return level;
  }();

  /// Whether [tile] holds ground of the map.
  bool has(GroundTile tile) =>
      tile.x >= 0 &&
      tile.y >= 0 &&
      tile.x * spanOf(tile.level) < width - 1 &&
      tile.y * spanOf(tile.level) < depth - 1;

  /// The coarsest tiles, which cover the map together.
  late final List<GroundTile> roots = [
    for (var y = 0; y * spanOf(rootLevel) < depth - 1; y++)
      for (var x = 0; x * spanOf(rootLevel) < width - 1; x++)
        (level: rootLevel, x: x, y: y),
  ];

  /// The root [tile] is under: itself for a root. Its cells are the page
  /// whose textures the tile is drawn with (`ground_pages.dart`).
  GroundTile rootOf(GroundTile tile) => (
    level: rootLevel,
    x: tile.x >> (rootLevel - tile.level),
    y: tile.y >> (rootLevel - tile.level),
  );

  /// The tiles one level finer that cover [tile]: up to four, fewer at the
  /// map's edge, none at level 0.
  List<GroundTile> childrenOf(GroundTile tile) => [
    if (tile.level > 0)
      for (final dy in const [0, 1])
        for (final dx in const [0, 1])
          if ((level: tile.level - 1, x: tile.x * 2 + dx, y: tile.y * 2 + dy)
              case final child when has(child))
            child,
  ];

  /// The cells [tile] covers. Its last column and row are its neighbours'
  /// first, so tiles of one level meet without a gap.
  CellRect cellsOf(GroundTile tile) {
    final span = spanOf(tile.level);
    final x0 = tile.x * span;
    final y0 = tile.y * span;
    return (
      x0: x0,
      y0: y0,
      x1: math.min(x0 + span, width - 1),
      y1: math.min(y0 + span, depth - 1),
    );
  }

  /// How far [eye], a point of the 3D world, is from the nearest ground of
  /// [cells], in metres.
  double distanceTo(CellRect cells, Vector3 eye, HeightAt heightAt) {
    final east = eye.x.clamp(
      (cells.x0 + 0.5) * cellSizeM,
      (cells.x1 + 0.5) * cellSizeM,
    );
    final south = (-eye.z).clamp(
      (cells.y0 + 0.5) * cellSizeM,
      (cells.y1 + 0.5) * cellSizeM,
    );
    return Vector3(
      east - eye.x,
      heightAt(east, south) - eye.y,
      -south - eye.z,
    ).length;
  }
}

/// What a [GroundSelector] chose: the tiles to `render`, which cover the
/// map without overlap, and the tiles to `load`, those and their ancestors,
/// the coarsest first and the nearest first within a level.
typedef GroundCut = ({List<GroundTile> render, List<GroundTile> load});

/// {@template ground_selector}
/// Chooses the tiles the ground is drawn with from where it is seen: fine
/// near the eye, coarse far away. A tile splits while one of its quads is
/// taller on screen than [detail], a fraction of the view's height, so the
/// choice follows the field of view and not the screen's resolution. A
/// split tile shows only once all its children are live; until then it
/// stands in for them, so the ground never has a hole.
/// {@endtemplate}
class GroundSelector {
  /// {@macro ground_selector}
  new({required this.grid, this.detail = 1 / 135});

  /// The map's tiles.
  final GroundGrid grid;

  /// The tallest a quad may be on screen, as a fraction of the view's
  /// height: 1/135 is 8 pixels of a view 1080 high.
  final double detail;

  /// The cut for an [eye] with the vertical field of view [fovY], over
  /// ground whose height is [heightAt]. [isLive] tells the tiles that can
  /// be drawn now.
  GroundCut select({
    required Vector3 eye,
    required double fovY,
    required HeightAt heightAt,
    required bool Function(GroundTile tile) isLive,
  }) {
    final view = 2 * math.tan(fovY / 2);
    final wanted = <GroundTile, double>{};

    bool cover(GroundTile tile, List<GroundTile> render) {
      final distance = math.max(
        grid.distanceTo(grid.cellsOf(tile), eye, heightAt),
        1,
      );
      wanted[tile] = distance.toDouble();
      final quad = grid.stepOf(tile.level) * grid.cellSizeM;
      final children = quad / (distance * view) > detail
          ? grid.childrenOf(tile)
          : const <GroundTile>[];
      if (children.isEmpty) {
        if (isLive(tile)) render.add(tile);
        return isLive(tile);
      }
      final finer = <GroundTile>[];
      var allReady = true;
      for (final child in children) {
        if (!cover(child, finer)) allReady = false;
      }
      if (allReady || !isLive(tile)) {
        render.addAll(finer);
        return allReady;
      }
      render.add(tile);
      return true;
    }

    final render = <GroundTile>[];
    for (final root in grid.roots) {
      cover(root, render);
    }
    final load = wanted.keys.toList()
      ..sort(
        (a, b) => a.level != b.level
            ? b.level - a.level
            : wanted[a]!.compareTo(wanted[b]!),
      );
    return (render: render, load: load);
  }
}

/// The vertex arrays of a ground tile: its `positions` in the 3D world, its
/// `texCoords`, where each vertex's cell is in the textures of the tile's
/// page, its `colors`, the grey of each vertex's slope, and its `indices`.
typedef GroundTileArrays = ({
  Float32List positions,
  Float32List texCoords,
  Float32List colors,
  Uint16List indices,
});

List<int> _stops(int from, int to, int step) => [
  for (var at = from; at < to; at += step) at,
  to,
];

/// The vertices around a grid of [cols] × [rows], in a loop.
List<int> _rim(int cols, int rows) => [
  for (var i = 0; i < cols; i++) i,
  for (var j = 1; j < rows; j++) j * cols + cols - 1,
  for (var i = cols - 2; i >= 0; i--) (rows - 1) * cols + i,
  for (var j = rows - 2; j >= 1; j--) j * cols,
];

/// The mesh of [tile]: a vertex at the centre of every `stepOf(level)`-th
/// cell, at its height, shaded by its slope towards a light from the
/// north-west as `terrainArrays` shades a whole map. The terrain and the fog
/// are not in the mesh: the ground's material reads them from the textures
/// of the tile's page (the cells of its root), at the centre of the texel
/// of each vertex's cell, so a coarse tile shows every cell it spans. A
/// skirt hangs from its edge, one quad deep, and hides the crack where it
/// meets a tile of another level.
GroundTileArrays groundTileArrays(
  MapData map,
  GroundGrid grid,
  GroundTile tile,
) {
  final cell = grid.cellSizeM;
  final step = grid.stepOf(tile.level);
  final rect = grid.cellsOf(tile);
  final page = grid.cellsOf(grid.rootOf(tile));
  final pageWidth = page.x1 - page.x0 + 1;
  final pageHeight = page.y1 - page.y0 + 1;
  final xs = _stops(rect.x0, rect.x1, step);
  final ys = _stops(rect.y0, rect.y1, step);
  final cols = xs.length;
  final rows = ys.length;
  final rim = _rim(cols, rows);
  final inner = cols * rows;
  final count = inner + rim.length;
  final positions = Float32List(count * 3);
  final texCoords = Float32List(count * 2);
  final colors = Float32List(count * 4);
  final light = Vector3(-1, 2, 1)..normalize();

  double height(int x, int y) => map
      .heights[y.clamp(0, map.depth - 1) * map.width +
          x.clamp(0, map.width - 1)]
      .toDouble();

  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      final x = xs[i];
      final y = ys[j];
      final v = j * cols + i;
      positions
        ..[v * 3] = (x + 0.5) * cell
        ..[v * 3 + 1] = height(x, y)
        ..[v * 3 + 2] = -(y + 0.5) * cell;
      final dEast = height(x + step, y) - height(x - step, y);
      final dNorth = height(x, y - step) - height(x, y + step);
      final normal = Vector3(-dEast, 2 * step * cell, -dNorth)..normalize();
      final shade = 0.55 + 0.45 * math.max(0, normal.dot(light));
      colors
        ..[v * 4] = shade
        ..[v * 4 + 1] = shade
        ..[v * 4 + 2] = shade
        ..[v * 4 + 3] = 1;
      texCoords
        ..[v * 2] = (x - page.x0 + 0.5) / pageWidth
        ..[v * 2 + 1] = (y - page.y0 + 0.5) / pageHeight;
    }
  }
  final skirt = step * cell;
  for (final (k, from) in rim.indexed) {
    final v = inner + k;
    positions
      ..[v * 3] = positions[from * 3]
      ..[v * 3 + 1] = positions[from * 3 + 1] - skirt
      ..[v * 3 + 2] = positions[from * 3 + 2];
    colors.setRange(v * 4, v * 4 + 4, colors, from * 4);
    texCoords.setRange(v * 2, v * 2 + 2, texCoords, from * 2);
  }

  final indices = Uint16List((cols - 1) * (rows - 1) * 6 + rim.length * 6);
  var at = 0;
  for (var j = 0; j < rows - 1; j++) {
    for (var i = 0; i < cols - 1; i++) {
      final a = j * cols + i;
      final b = a + 1;
      final c = a + cols;
      final d = c + 1;
      indices
        ..[at++] = a
        ..[at++] = c
        ..[at++] = b
        ..[at++] = b
        ..[at++] = c
        ..[at++] = d;
    }
  }
  for (var k = 0; k < rim.length; k++) {
    final next = (k + 1) % rim.length;
    indices
      ..[at++] = rim[k]
      ..[at++] = rim[next]
      ..[at++] = inner + k
      ..[at++] = rim[next]
      ..[at++] = inner + next
      ..[at++] = inner + k;
  }
  return (
    positions: positions,
    texCoords: texCoords,
    colors: colors,
    indices: indices,
  );
}

/// A square of cells whose objects are drawn together: [groundTileQuads]
/// cells wide unless said otherwise.
typedef ChunkId = ({int x, int y});

/// The objects of a chunk that are drawn: the cells (`y × width + x`) of its
/// `trees` and of its `buildings`.
typedef ObjectChunk = ({List<int> trees, List<int> buildings});

/// The trees and buildings of [map] by chunk of [cells] cells, so that only
/// those near the eye are drawn.
Map<ChunkId, ObjectChunk> objectChunks(
  MapData map, {
  int cells = groundTileQuads,
}) {
  final chunks = <ChunkId, ObjectChunk>{};
  for (final feature in map.features.features) {
    final tree = feature.type == 'tree';
    if (!tree && feature.type != 'building') continue;
    for (final cell in feature.cells) {
      final chunk = chunks[(x: cell.x ~/ cells, y: cell.y ~/ cells)] ??= (
        trees: [],
        buildings: [],
      );
      (tree ? chunk.trees : chunk.buildings).add(cell.y * map.width + cell.x);
    }
  }
  return chunks;
}

/// The cells of the chunk [id] in [grid], for chunks of [cells] cells.
CellRect chunkCells(
  GroundGrid grid,
  ChunkId id, {
  int cells = groundTileQuads,
}) => (
  x0: id.x * cells,
  y0: id.y * cells,
  x1: math.min((id.x + 1) * cells, grid.width) - 1,
  y1: math.min((id.y + 1) * cells, grid.depth) - 1,
);

/// The chunks of [cells] cells that may hold ground within [rangeM] metres
/// of [eye]: those of the square around it, cut at the map's edge. The
/// range is taken on the ground, so none within it in 3D is missed.
List<ChunkId> chunksAround(
  GroundGrid grid,
  Vector3 eye,
  double rangeM, {
  int cells = groundTileQuads,
}) {
  final side = cells * grid.cellSizeM;
  int first(double at) => math.max(0, ((at - rangeM) / side).floor());
  int last(double at, int count) =>
      math.min((count - 1) ~/ cells, ((at + rangeM) / side).floor());
  return [
    for (var y = first(-eye.z); y <= last(-eye.z, grid.depth); y++)
      for (var x = first(eye.x); x <= last(eye.x, grid.width); x++)
        (x: x, y: y),
  ];
}

/// How the trees of a chunk are drawn: with their model, with the cone that
/// stands for it far away, or not at all.
enum TreeLevel {
  /// The model of each tree.
  near,

  /// A cone in the colour of the leaves.
  far,

  /// Nothing: the colour of the ground stands for the forest.
  none,
}

/// The level of a chunk of trees whose nearest ground is [distance] metres
/// from the eye: [TreeLevel.near] within [nearM], [TreeLevel.far] within
/// [rangeM]. A chunk keeps the level it has ([now]) until it is past the
/// limit by [margin], so it does not flicker while the eye hovers there.
TreeLevel treeLevelAt(
  double distance, {
  required TreeLevel now,
  required double nearM,
  required double rangeM,
  double margin = 1.25,
}) {
  if (distance <= nearM || (now == .near && distance <= nearM * margin)) {
    return .near;
  }
  if (distance <= rangeM || (now != .none && distance <= rangeM * margin)) {
    return .far;
  }
  return .none;
}

/// The far model of a tree: a cone of [sides] triangles without a base,
/// one unit tall and one in radius, standing on the origin; each tree
/// scales it to its own crown. The normals are those of a cone three times
/// taller than wide, about what a tree is.
({Float32List positions, Float32List normals, Uint16List indices})
treeConeArrays({int sides = 6}) {
  final positions = Float32List(sides * 2 * 3);
  final normals = Float32List(sides * 2 * 3);
  final indices = Uint16List(sides * 3);
  final slope = Vector3(3, 1, 0)..normalize();
  for (var i = 0; i < sides; i++) {
    final angle = 2 * math.pi * i / sides;
    // The apex has a vertex a side, so each takes the normal of its side.
    final middle = 2 * math.pi * (i + 0.5) / sides;
    final apex = sides + i;
    positions
      ..[i * 3] = math.cos(angle)
      ..[i * 3 + 2] = math.sin(angle)
      ..[apex * 3 + 1] = 1;
    normals
      ..[i * 3] = math.cos(angle) * slope.x
      ..[i * 3 + 1] = slope.y
      ..[i * 3 + 2] = math.sin(angle) * slope.x
      ..[apex * 3] = math.cos(middle) * slope.x
      ..[apex * 3 + 1] = slope.y
      ..[apex * 3 + 2] = math.sin(middle) * slope.x;
    indices
      ..[i * 3] = i
      ..[i * 3 + 1] = apex
      ..[i * 3 + 2] = (i + 1) % sides;
  }
  return (positions: positions, normals: normals, indices: indices);
}

/// How the tree of the map cell [cell] is drawn, so that a forest is not a
/// grid of copies: moved `east` and `south` within its cell (a fraction of
/// the cell), turned by `yaw` radians, scaled by `scale`, and of the model
/// `kind` picks (a fraction of the list of models, under 1). The same for a
/// cell every time. Only the drawing varies; the battle keeps the tree at
/// its cell.
({double east, double south, double yaw, double scale, double kind}) treeLook(
  int cell,
) {
  double part(int a, int b) => (cell % 100003 * a + b) % 9973 / 9973;
  return (
    east: (part(7919, 17) - 0.5) * 0.5,
    south: (part(6271, 4099) - 0.5) * 0.5,
    yaw: part(3571, 911) * 2 * math.pi,
    scale: 0.8 + part(5119, 2749) * 0.45,
    kind: part(4421, 6007),
  );
}
