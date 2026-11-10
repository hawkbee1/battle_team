// coverage:ignore-file
// Draws through flutter_scene, which needs a GPU context that
// `flutter test` does not have.

import 'dart:math' as math;

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// The colour of [team]'s units, HQ and relics.
Vector4 teamColor(String? team) => switch (team) {
  'blue' => Vector4(0.15, 0.40, 0.95, 1),
  'red' => Vector4(0.90, 0.20, 0.15, 1),
  null => Vector4(0.95, 0.80, 0.20, 1),
  _ => Vector4(0.7, 0.7, 0.7, 1),
};

const _vehicles = {'jeep', 'tank', 'truck', 'artillery'};

/// {@template scene_battle_world}
/// The battle in 3D with flutter_scene, the renderer behind the `BattleWorld`
/// Strategy: the map's ground, its trees and buildings, and what the section
/// sees (units, HQs, relics), each unit gliding to where the host put it by
/// its move's arrival time (decision 236). Units are drawn about three times
/// their size so they show from above.
/// {@endtemplate}
class SceneBattleWorld implements BattleWorld {
  /// {@macro scene_battle_world}
  new(this.map) : surface = TerrainSurface(map);

  /// The map.
  final MapData map;

  @override
  final TerrainSurface surface;

  /// The scene, built on first use: read it only once
  /// `Scene.initializeStaticResources()` completed.
  late final Scene scene = _build();

  final _units = <String, _Glide>{};
  final _hqs = <String, Node>{};
  final _relics = <String, Node>{};
  double _clock = 0;

  @override
  Map<String, Vector3> get drawn => {
    for (final MapEntry(:key, :value) in _units.entries) key: value.at(_clock),
  };

  Scene _build() {
    final scene = Scene();
    final ground = terrainArrays(map);
    scene.add(
      Node(
        name: 'ground',
        mesh: Mesh(
          MeshGeometry.fromArrays(
            positions: ground.positions,
            colors: ground.colors,
            indices: ground.indices,
          ),
          UnlitMaterial()..doubleSided = true,
        ),
      ),
    );
    final trees = InstancedMesh(
      geometry: CylinderGeometry(
        bottomRadius: 3.5,
        height: 9,
        radialSegments: 8,
      ),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.16, 0.33, 0.14, 1)
        ..roughnessFactor = 0.9,
    );
    final buildings = InstancedMesh(
      geometry: CuboidGeometry(Vector3(8, 6, 8)),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.72, 0.62, 0.52, 1)
        ..roughnessFactor = 0.8,
    );
    final cell = surface.cell;
    for (final feature in map.features.features) {
      final mesh = switch (feature.type) {
        'tree' => trees,
        'building' => buildings,
        _ => null,
      };
      if (mesh == null) continue;
      final lift = mesh == trees ? 4.5 : 3.0;
      for (final at in feature.cells) {
        final east = (at.x + 0.5) * cell;
        final south = (at.y + 0.5) * cell;
        mesh.addInstance(
          Matrix4.translation(
            Vector3(east, surface.heightAt(east, south) + lift, -south),
          ),
        );
      }
    }
    scene
      ..add(Node(name: 'trees')..addComponent(InstancedMeshComponent(trees)))
      ..add(
        Node(name: 'buildings')
          ..addComponent(InstancedMeshComponent(buildings)),
      );
    return scene;
  }

  @override
  void show({
    required Iterable<UnitView> units,
    required Iterable<HqView> hqs,
    required Iterable<RelicView> relics,
    required String? selected,
    required Duration? battleTime,
  }) {
    final placed = <String, Vector3>{
      for (final unit in units)
        if (unit.position case final position?)
          unit.unitId: _onGround(position),
    };
    final targets = fanOut(placed);
    for (final unit in units) {
      final target = targets[unit.unitId];
      if (target == null) continue;
      target.y = surface.heightAt(target.x, -target.z);
      final glide = _units[unit.unitId] ??= _Glide(
        _unitNode(unit)..also(scene.add),
        target,
      );
      if (glide.to != target) {
        final until = unit.private?.movingUntil;
        final seconds = until != null && battleTime != null
            ? math.max(0, (until - battleTime).inMilliseconds / 1000)
            : 0.5;
        glide.retarget(target, now: _clock, seconds: seconds.toDouble());
      }
      glide.node.highlightColor = unit.unitId == selected
          ? Vector4(1, 1, 0.3, 1)
          : null;
    }
    for (final id in _units.keys.toList()) {
      if (!targets.containsKey(id)) scene.remove(_units.remove(id)!.node);
    }
    _place(_hqs, {
      for (final hq in hqs) hq.team: (hq.position, hq.team),
    }, (team) => _flag(teamColor(team)));
    _place(_relics, {
      for (final relic in relics) relic.relicId: (relic.position, relic.owner),
    }, (owner) => _pillar(teamColor(owner)));
    tick(0);
  }

  @override
  void tick(double seconds) {
    _clock += seconds;
    for (final glide in _units.values) {
      final at = glide.at(_clock);
      glide.node.localTransform = Matrix4.translation(at);
    }
  }

  Vector3 _onGround(Position position) {
    final world = worldOf(position);
    return world..y = surface.heightAt(world.x, -world.z);
  }

  void _place(
    Map<String, Node> nodes,
    Map<String, (Position, String?)> wanted,
    Node Function(String? team) make,
  ) {
    for (final id in nodes.keys.toList()) {
      if (!wanted.containsKey(id)) scene.remove(nodes.remove(id)!);
    }
    for (final MapEntry(key: id, value: (position, team)) in wanted.entries) {
      (nodes[id] ??= make(team)..also(scene.add)).localTransform =
          Matrix4.translation(_onGround(position));
    }
  }

  Node _unitNode(UnitView unit) {
    final color = teamColor(unit.team);
    final vehicle = _vehicles.contains(unit.unitType);
    final body = vehicle
        ? Node(
            mesh: Mesh(CuboidGeometry(Vector3(7, 4, 10)), _paint(color)),
            localTransform: Matrix4.translation(Vector3(0, 2, 0)),
          )
        : Node(
            mesh: Mesh(
              CapsuleGeometry(
                radius: unit.unitType == 'commander' ? 2.2 : 1.6,
                height: 6,
                radialSegments: 12,
                capRings: 4,
              ),
              _paint(color),
            ),
            localTransform: Matrix4.translation(Vector3(0, 3, 0)),
          );
    final base = Node(
      mesh: Mesh(
        DiscGeometry(radius: 3, segments: 24),
        UnlitMaterial()
          ..baseColorFactor = color
          ..doubleSided = true,
      ),
      localTransform: Matrix4.translation(Vector3(0, 0.3, 0)),
    );
    return Node(name: unit.unitId)
      ..add(base)
      ..add(body);
  }

  /// An HQ: a ring on the ground around its units and a flag on a pole.
  static Node _flag(Vector4 color) => Node()
    ..add(
      Node(
        mesh: Mesh(
          RingGeometry(innerRadius: 10, outerRadius: 12, segments: 48),
          UnlitMaterial()
            ..baseColorFactor = color
            ..doubleSided = true,
        ),
        localTransform: Matrix4.translation(Vector3(0, 0.4, 0)),
      ),
    )
    ..add(
      Node(
        mesh: Mesh(
          CylinderGeometry(bottomRadius: 0.4, topRadius: 0.4, height: 24),
          _paint(Vector4(0.85, 0.85, 0.85, 1)),
        ),
        localTransform: Matrix4.translation(Vector3(-11, 12, 0)),
      ),
    )
    ..add(
      Node(
        mesh: Mesh(CuboidGeometry(Vector3(8, 5, 0.4)), _paint(color)),
        localTransform: Matrix4.translation(Vector3(-7, 21, 0)),
      ),
    );

  static Node _pillar(Vector4 color) => Node()
    ..add(
      Node(
        mesh: Mesh(
          CylinderGeometry(bottomRadius: 3, topRadius: 3, height: 12),
          _paint(color),
        ),
        localTransform: Matrix4.translation(Vector3(0, 6, 0)),
      ),
    );

  static PhysicallyBasedMaterial _paint(Vector4 color) =>
      PhysicallyBasedMaterial()
        ..baseColorFactor = color
        ..roughnessFactor = 0.6;
}

/// A unit's node gliding from [from] to [to] between two clock times.
class _Glide {
  new(this.node, Vector3 at) : from = at.clone(), to = at.clone();

  final Node node;
  Vector3 from;
  Vector3 to;
  double _start = 0;
  double _end = 0;

  void retarget(
    Vector3 target, {
    required double now,
    required double seconds,
  }) {
    from = at(now);
    to = target.clone();
    _start = now;
    _end = now + seconds;
  }

  Vector3 at(double now) {
    if (now >= _end || _end <= _start) return to.clone();
    final t = (now - _start) / (_end - _start);
    return from + (to - from) * t;
  }
}

extension<T> on T {
  /// Calls [use] with this, then gives it back.
  T also(void Function(T) use) {
    use(this);
    return this;
  }
}
