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
import 'package:battle_team/battle/world/ground_tiles.dart';
import 'package:battle_team/battle/world/tree_model.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// {@template ground_streamer}
/// Keeps in the [scene] the ground and the objects worth drawing from where
/// the battle is seen: the ground as the tiles a `GroundSelector` chooses,
/// fine near the eye and coarse far away, and the trees and buildings of the
/// chunks within [objectRangeM] of the eye. Meshes are made a few a frame
/// ([tileBuildsPerFrame], [chunkBuildsPerFrame]), so moving never stalls a
/// frame, and are dropped once out of the cut or out of range.
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
    required this.tree,
    this.tileBuildsPerFrame = 6,
    this.chunkBuildsPerFrame = 2,
    this.fogUpdatesPerFrame = 12,
    this.objectRangeM = 1500,
  });

  /// The scene the meshes are added to.
  final Scene scene;

  /// The map.
  final MapData map;

  /// The ground of the map.
  final TerrainSurface surface;

  /// The model every tree is drawn with.
  final TreeModel tree;

  /// The ground tiles made in a frame at most; the roots are all made at
  /// once, so there is ground from the first frame.
  final int tileBuildsPerFrame;

  /// The chunks of objects made in a frame at most.
  final int chunkBuildsPerFrame;

  /// The ground tiles whose fog is redrawn in a frame at most.
  final int fogUpdatesPerFrame;

  /// How far from the eye trees and buildings are drawn, in metres. Beyond
  /// it a forest shows by the colour of its ground.
  final double objectRangeM;

  late final GroundGrid _grid = GroundGrid.of(map);
  late final GroundSelector _selector = GroundSelector(grid: _grid);
  late final Map<ChunkId, ObjectChunk> _chunks = objectChunks(map);

  final _groundMaterial = UnlitMaterial()..doubleSided = true;
  late final Geometry _buildingGeometry = CuboidGeometry(Vector3(8, 6, 8));
  late final Material _buildingMaterial = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(0.72, 0.62, 0.52, 1)
    ..roughnessFactor = 0.8;

  final _tiles = <GroundTile, _LiveTile>{};
  final _objects = <ChunkId, Node>{};
  FogModel? _fog;
  int _fogVersion = 0;
  Vector3? _settledEye;
  double? _settledFov;

  /// The ground tiles on the GPU, and those of them drawn now: for a
  /// debug overlay.
  ({int live, int drawn, int chunks}) get counts => (
    live: _tiles.length,
    drawn: _tiles.values.where((tile) => tile.node.visible).length,
    chunks: _objects.length,
  );

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
    if (groundDone && fogDone && objectsDone) {
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

  /// Whether the objects in range of [eye] are all made.
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
      }
    }
    missing.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, id) in missing.take(chunkBuildsPerFrame)) {
      _objects[id] = _makeObjects(id, _chunks[id]!)..also(scene.add);
    }
    return missing.length <= chunkBuildsPerFrame;
  }

  /// The trees and buildings of a chunk: one instanced mesh per part of the
  /// tree model and one for the buildings, so a chunk is a few draws.
  Node _makeObjects(ChunkId id, ObjectChunk chunk) {
    final cell = surface.cell;
    final node = Node(name: 'objects_${id.x}_${id.y}');
    if (chunk.trees.isNotEmpty) {
      final parts = [
        for (final part in tree.parts)
          InstancedMesh(geometry: part.geometry, material: part.material),
      ];
      final up = Vector3(0, 1, 0);
      for (final index in chunk.trees) {
        final look = treeLook(index);
        final east = (index % map.width + 0.5 + look.east) * cell;
        final south = (index ~/ map.width + 0.5 + look.south) * cell;
        // The model's foot stands on the ground.
        final foot = Matrix4.compose(
          Vector3(
            east,
            surface.heightAt(east, south) - tree.baseY * look.scale,
            -south,
          ),
          Quaternion.axisAngle(up, look.yaw),
          Vector3.all(look.scale),
        );
        for (final (at, part) in tree.parts.indexed) {
          parts[at].addInstance(foot.multiplied(part.transform));
        }
      }
      for (final mesh in parts) {
        node.add(Node()..addComponent(InstancedMeshComponent(mesh)));
      }
    }
    if (chunk.buildings.isNotEmpty) {
      final buildings = InstancedMesh(
        geometry: _buildingGeometry,
        material: _buildingMaterial,
      );
      for (final index in chunk.buildings) {
        final east = (index % map.width + 0.5) * cell;
        final south = (index ~/ map.width + 0.5) * cell;
        buildings.addInstance(
          Matrix4.translation(
            Vector3(east, surface.heightAt(east, south) + 3, -south),
          ),
        );
      }
      node.add(Node()..addComponent(InstancedMeshComponent(buildings)));
    }
    return node;
  }
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
