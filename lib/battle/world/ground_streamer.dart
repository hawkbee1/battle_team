// coverage:ignore-file
// Draws through flutter_scene, which needs a GPU context that
// `flutter test` does not have.
//
// POC (branch poc/streamed-world). The streaming loop (a budget of builds a
// frame, coarse tiles standing in for fine ones) is adapted from dashmap
// (https://github.com/bdero/dashmap, MIT, Copyright (c) 2026 Brandon
// DeRosier): `terrain_streamer.dart`.

import 'dart:typed_data';

import 'package:battle_map/battle_map.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/building_mesh.dart';
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/battle/world/tree_model.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// {@template ground_streamer}
/// Keeps in the [scene] the ground and the objects worth drawing from where
/// the battle is seen: the ground as the tiles a `GroundSelector` chooses,
/// fine near the eye and coarse far away, and the trees and buildings of the
/// chunks within [objectRangeM] of the eye. A chunk of trees draws the model
/// of each tree within [treeNearM] and a cone for each beyond. The buildings
/// of a chunk are a few meshes made in code (`buildingArrays`). Meshes are
/// made a few a frame ([tileBuildsPerFrame], [chunkBuildsPerFrame],
/// [treeBuildsPerFrame]), so moving never stalls a frame, and are dropped
/// once out of the cut or out of range.
///
/// The whole map stays in memory as `MapData`; only what is on the GPU
/// follows the eye.
/// {@endtemplate}
class GroundStreamer {
  /// {@macro ground_streamer}
  new({
    required this.scene,
    required this.map,
    required this.surface,
    required this.trees,
    this.tileBuildsPerFrame = 6,
    this.chunkBuildsPerFrame = 2,
    this.treeBuildsPerFrame = 8,
    this.fogUpdatesPerFrame = 12,
    this.objectRangeM = 1500,
    this.treeNearM = 100,
    this.treeChunkCells = 16,
  });

  /// The scene the meshes are added to.
  final Scene scene;

  /// The map.
  final MapData map;

  /// The ground of the map.
  final TerrainSurface surface;

  /// The models the trees are drawn with; `treeLook` picks one for each
  /// cell. Without any, no tree is drawn.
  final List<TreeModel> trees;

  /// The ground tiles made in a frame at most; the roots are all made at
  /// once, so there is ground from the first frame.
  final int tileBuildsPerFrame;

  /// The chunks of buildings made in a frame at most.
  final int chunkBuildsPerFrame;

  /// The meshes of trees made in a frame at most: a chunk's models or its
  /// cones.
  final int treeBuildsPerFrame;

  /// The ground tiles whose fog is redrawn in a frame at most.
  final int fogUpdatesPerFrame;

  /// How far from the eye trees and buildings are drawn, in metres. Beyond
  /// it a forest shows by the colour of its ground.
  final double objectRangeM;

  /// How far from the eye a chunk of trees draws their models, in metres,
  /// measured to the chunk's nearest ground. Beyond it a tree is a cone.
  final double treeNearM;

  /// The cells along the side of a chunk of trees. A chunk has one level
  /// for all its trees, so the smaller it is, the fewer models are drawn
  /// past [treeNearM] and the more draws a forest costs: in the densest
  /// forest of `saint_lo`, 2,304 models at once with 16 cells, 4,041 with
  /// 32 and 8,824 with 64.
  final int treeChunkCells;

  late final GroundGrid _grid = GroundGrid.of(map);
  late final GroundSelector _selector = GroundSelector(grid: _grid);
  late final Map<ChunkId, ObjectChunk> _chunks = objectChunks(map);
  late final Map<ChunkId, ObjectChunk> _treeChunks = trees.isEmpty
      ? const {}
      : objectChunks(map, cells: treeChunkCells);

  final _groundMaterial = UnlitMaterial()..doubleSided = true;
  late final Set<int> _buildingCells = {
    for (final chunk in _chunks.values) ...chunk.buildings,
  };
  // The roofs and the walls take their colours from the vertices.
  // Double-sided, so a building does not depend on the winding flutter_scene
  // culls.
  late final Material _buildingMaterial = PhysicallyBasedMaterial()
    ..roughnessFactor = 0.8
    ..doubleSided = true;
  late final Geometry _coneGeometry = () {
    final cone = treeConeArrays();
    return MeshGeometry.fromArrays(
      positions: cone.positions,
      normals: cone.normals,
      indices: cone.indices,
    );
  }();
  // Each cone takes the colour of its tree's leaves as its instance colour.
  // Double-sided, so the cone does not depend on the winding flutter_scene
  // culls.
  late final Material _coneMaterial = PhysicallyBasedMaterial()
    ..roughnessFactor = 0.9
    ..doubleSided = true;

  final _tiles = <GroundTile, _LiveTile>{};
  final _objects = <ChunkId, Node>{};
  final _buildingTriangles = <ChunkId, int>{};
  final _trees = <ChunkId, _LiveTrees>{};
  FogModel? _fog;
  int _fogVersion = 0;
  Vector3? _settledEye;
  double? _settledFov;

  /// The ground tiles on the GPU, those of them drawn now, the chunks of
  /// buildings, their meshes and their triangles, and the trees drawn as
  /// models and as cones: for a debug overlay.
  ({
    int live,
    int drawn,
    int chunks,
    int buildingMeshes,
    int buildingTriangles,
    int nearTrees,
    int farTrees,
  })
  get counts {
    var nearTrees = 0;
    var farTrees = 0;
    for (final MapEntry(key: id, value: live) in _trees.entries) {
      final count = _treeChunks[id]!.trees.length;
      if (live.near?.visible ?? false) nearTrees += count;
      if (live.far?.visible ?? false) farTrees += count;
    }
    return (
      live: _tiles.length,
      drawn: _tiles.values.where((tile) => tile.node.visible).length,
      chunks: _objects.length,
      buildingMeshes: _objects.values.fold(
        0,
        (sum, node) => sum + node.children.length,
      ),
      buildingTriangles: _buildingTriangles.values.fold(0, (a, b) => a + b),
      nearTrees: nearTrees,
      farTrees: farTrees,
    );
  }

  /// Shades the ground by [fog] from now on. The tiles are redrawn over the
  /// next frames, the ones on screen first.
  void showFog(FogModel fog) {
    _fog = fog;
    _fogVersion++;
    _settledEye = null;
  }

  /// Brings the scene to what [camera] sees. Call it every frame: it does
  /// nothing while the eye stays where everything was already made for it.
  void update(BattleCamera camera) {
    final eye = camera.position;
    if (_settledFov == camera.fovY &&
        _settledEye != null &&
        (eye - _settledEye!).length < 2) {
      return;
    }
    final groundDone = _updateGround(eye, camera.fovY);
    final fogDone = _updateFog();
    final objectsDone = _updateObjects(eye);
    final treesDone = _updateTrees(eye);
    if (groundDone && fogDone && objectsDone && treesDone) {
      _settledEye = eye.clone();
      _settledFov = camera.fovY;
    } else {
      _settledEye = null;
    }
  }

  /// Whether the ground is all made for [eye].
  bool _updateGround(Vector3 eye, double fovY) {
    final cut = _selector.select(
      eye: eye,
      fovY: fovY,
      heightAt: surface.heightAt,
      isLive: _tiles.containsKey,
    );
    final keep = cut.load.toSet();
    for (final tile in _tiles.keys.toList()) {
      if (!keep.contains(tile)) scene.remove(_tiles.remove(tile)!.node);
    }
    final render = cut.render.toSet();
    for (final MapEntry(key: tile, value: live) in _tiles.entries) {
      live.node.visible = render.contains(tile);
    }
    var budget = tileBuildsPerFrame;
    var done = true;
    for (final tile in cut.load) {
      if (_tiles.containsKey(tile)) continue;
      // A tile made now shows from the next cut, which sees it live.
      done = false;
      if (budget <= 0 && tile.level != _grid.rootLevel) break;
      _tiles[tile] = _makeTile(tile, visible: tile.level == _grid.rootLevel);
      budget--;
    }
    return done;
  }

  _LiveTile _makeTile(GroundTile tile, {required bool visible}) {
    final arrays = groundTileArrays(map, _grid, tile);
    final fog = _fog;
    final geometry = MeshGeometry.fromArrays(
      positions: arrays.positions,
      colors: fog == null
          ? arrays.colors
          : fogShadedTileColors(arrays.colors, arrays.cells, fog),
      indices: arrays.indices,
      storage: GeometryStorage.updatable,
    );
    final node = Node(
      name: 'ground_${tile.level}_${tile.x}_${tile.y}',
      mesh: Mesh(geometry, _groundMaterial),
    )..visible = visible;
    scene.add(node);
    return _LiveTile(node, geometry, arrays.colors, arrays.cells, _fogVersion);
  }

  /// Whether every tile shows the current fog.
  bool _updateFog() {
    final fog = _fog;
    if (fog == null) return true;
    final stale = [
      for (final tile in _tiles.values)
        if (tile.fogVersion != _fogVersion) tile,
    ]..sort((a, b) => (a.node.visible ? 0 : 1) - (b.node.visible ? 0 : 1));
    for (final tile in stale.take(fogUpdatesPerFrame)) {
      tile.geometry.updateColors(
        fogShadedTileColors(tile.base, tile.cells, fog),
      );
      tile.fogVersion = _fogVersion;
    }
    return stale.length <= fogUpdatesPerFrame;
  }

  /// Whether the buildings in range of [eye] are all made.
  bool _updateObjects(Vector3 eye) {
    final missing = <(double, ChunkId)>[];
    for (final id in _chunks.keys) {
      final distance = _grid.distanceTo(
        chunkCells(_grid, id),
        eye,
        surface.heightAt,
      );
      if (distance <= objectRangeM) {
        if (!_objects.containsKey(id)) missing.add((distance, id));
      } else if (distance > objectRangeM * 1.25) {
        // Past the range by a margin, so a chunk at its edge is not made and
        // dropped again as the eye hovers there.
        final node = _objects.remove(id);
        if (node != null) scene.remove(node);
        _buildingTriangles.remove(id);
      }
    }
    missing.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, id) in missing.take(chunkBuildsPerFrame)) {
      _objects[id] = _makeObjects(id, _chunks[id]!)..also(scene.add);
    }
    return missing.length <= chunkBuildsPerFrame;
  }

  /// The buildings of a chunk, as the meshes of `buildingArrays`: a wall
  /// only where no building stands next door, in this chunk or another.
  Node _makeObjects(ChunkId id, ObjectChunk chunk) {
    final node = Node(name: 'objects_${id.x}_${id.y}');
    final meshes = buildingArrays(
      cells: chunk.buildings,
      width: map.width,
      cellSizeM: surface.cell,
      heightAt: surface.heightAt,
      isBuilding: (x, y) =>
          x >= 0 &&
          x < map.width &&
          y >= 0 &&
          y < map.depth &&
          _buildingCells.contains(y * map.width + x),
    );
    var triangles = 0;
    for (final arrays in meshes) {
      triangles += arrays.indices.length ~/ 3;
      node.add(
        Node(
          mesh: Mesh(
            MeshGeometry.fromArrays(
              positions: arrays.positions,
              normals: arrays.normals,
              colors: arrays.colors,
              indices: arrays.indices,
            ),
            _buildingMaterial,
          ),
        ),
      );
    }
    _buildingTriangles[id] = triangles;
    return node;
  }

  /// Whether the trees in range of [eye] are all drawn at their level.
  bool _updateTrees(Vector3 eye) {
    final missing = <(double, ChunkId, TreeLevel)>[];
    final around = chunksAround(
      _grid,
      eye,
      objectRangeM,
      cells: treeChunkCells,
    ).where(_treeChunks.containsKey);
    // The chunks on the GPU too: one left behind by a jump of the eye is
    // dropped here.
    for (final id in {...around, ..._trees.keys}) {
      final distance = _grid.distanceTo(
        chunkCells(_grid, id, cells: treeChunkCells),
        eye,
        surface.heightAt,
      );
      final live = _trees[id];
      final level = treeLevelAt(
        distance,
        now: live?.level ?? .none,
        nearM: treeNearM,
        rangeM: objectRangeM,
      );
      if (level == .none) {
        if (live != null) {
          if (live.near case final near?) scene.remove(near);
          if (live.far case final far?) scene.remove(far);
          _trees.remove(id);
        }
        continue;
      }
      if (live != null) {
        live.level = level;
        // The models of a chunk gone far are dropped; its cones stay while
        // it is near, so going far again makes nothing.
        if (level == .far && live.near != null) {
          scene.remove(live.near!);
          live.near = null;
        }
        // Until the mesh of its level is made, a chunk shows the other.
        live.near?.visible = level == .near;
        live.far?.visible = level == .far || live.near == null;
      }
      if ((level == .near ? live?.near : live?.far) == null) {
        missing.add((distance, id, level));
      }
    }
    missing.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, id, level) in missing.take(treeBuildsPerFrame)) {
      final live = _trees[id] ??= _LiveTrees(level);
      final cells = _treeChunks[id]!.trees;
      if (level == .near) {
        live.near = _makeNearTrees(id, cells)..also(scene.add);
        live.far?.visible = false;
      } else {
        live.far = _makeFarTrees(id, cells)..also(scene.add);
      }
    }
    return missing.length <= treeBuildsPerFrame;
  }

  /// The model of the tree of [cell], and where it stands: the transform
  /// from the model's frame to the world.
  (TreeModel, Matrix4) _treeAt(int cell) {
    final look = treeLook(cell);
    final model = trees[(look.kind * trees.length).floor()];
    final east = (cell % map.width + 0.5 + look.east) * surface.cell;
    final south = (cell ~/ map.width + 0.5 + look.south) * surface.cell;
    final scale = model.metresPerUnit * look.scale;
    return (
      model,
      // The model's foot stands on the ground.
      Matrix4.compose(
        Vector3(
          east,
          surface.heightAt(east, south) - model.baseY * scale,
          -south,
        ),
        Quaternion.axisAngle(Vector3(0, 1, 0), look.yaw),
        Vector3.all(scale),
      ),
    );
  }

  /// The trees of a chunk as their models: one instanced mesh per part of
  /// each model.
  Node _makeNearTrees(ChunkId id, List<int> cells) {
    final meshes = <TreePart, InstancedMesh>{};
    for (final cell in cells) {
      final (model, foot) = _treeAt(cell);
      for (final part in model.parts) {
        (meshes[part] ??= InstancedMesh(
          geometry: part.geometry,
          material: part.material,
        )).addInstance(foot.multiplied(part.transform));
      }
    }
    final node = Node(name: 'trees_near_${id.x}_${id.y}');
    for (final mesh in meshes.values) {
      node.add(Node()..addComponent(InstancedMeshComponent(mesh)));
    }
    return node;
  }

  /// The trees of a chunk as cones, in one instanced mesh: each cone as
  /// tall and as wide as its tree, in the colour of its leaves.
  Node _makeFarTrees(ChunkId id, List<int> cells) {
    final cones = InstancedMesh(
      geometry: _coneGeometry,
      material: _coneMaterial,
    );
    for (final cell in cells) {
      final (model, foot) = _treeAt(cell);
      final (red, green, blue) = model.leaves;
      cones.addInstance(
        foot.multiplied(
          Matrix4.compose(
            Vector3(model.centreX, model.baseY, model.centreZ),
            Quaternion.identity(),
            Vector3(model.radius, model.height, model.radius),
          ),
        ),
        color: Vector4(red, green, blue, 1),
      );
    }
    return Node(name: 'trees_far_${id.x}_${id.y}')
      ..addComponent(InstancedMeshComponent(cones));
  }
}

/// The trees of a chunk on the GPU: the level they are drawn at, and the
/// node of their models and of their cones, each once made.
class _LiveTrees {
  new(this.level);

  TreeLevel level;
  Node? near;
  Node? far;
}

/// A ground tile on the GPU: its node, its geometry, whose colours change
/// with the fog, and what they are made from.
class _LiveTile {
  new(this.node, this.geometry, this.base, this.cells, this.fogVersion);

  final Node node;
  final MeshGeometry geometry;
  final Float32List base;
  final Int32List cells;
  int fogVersion;
}

extension<T> on T {
  /// Calls [use] with this, then gives it back.
  T also(void Function(T) use) {
    use(this);
    return this;
  }
}
