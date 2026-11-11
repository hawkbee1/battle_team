// coverage:ignore-file
// Draws through flutter_scene, which needs a GPU context that
// `flutter test` does not have.

import 'dart:math' as math;

import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/battle/world/live_shots.dart';
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
/// its move's arrival time (decision 236), and the shots it sees for a moment
/// each (`LiveShots` keeps their lives; this class only draws them). Units are
/// drawn about three times their size so they show from above.
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
  final _shots = LiveShots();
  final _shotNodes = <LiveShot, _ShotNode>{};
  final _pathNodes = <Node>[];
  List<Position>? _pathPoints;
  double _clock = 0;
  String? _insideUnit;

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
    required String? target,
    required Duration? battleTime,
  }) {
    final placed = <String, Vector3>{
      for (final unit in units)
        if (unit.position case final position?)
          unit.unitId: _onGround(position),
    };
    final spread = fanOut(placed);
    for (final unit in units) {
      final to = spread[unit.unitId];
      if (to == null) continue;
      to.y = surface.heightAt(to.x, -to.z);
      final glide = _units[unit.unitId] ??= _Glide(
        _unitNode(unit)..also(scene.add),
        to,
      );
      if (glide.to != to) {
        final until = unit.private?.movingUntil;
        final seconds = until != null && battleTime != null
            ? math.max(0, (until - battleTime).inMilliseconds / 1000)
            : 0.5;
        glide.retarget(to, now: _clock, seconds: seconds.toDouble());
      }
      glide.node.highlightColor = switch (unit.unitId) {
        final id when id == selected => Vector4(1, 1, 0.3, 1),
        final id when id == target => Vector4(1, 1, 1, 1),
        _ => null,
      };
    }
    _hideInsideUnit();
    for (final id in _units.keys.toList()) {
      if (!spread.containsKey(id)) scene.remove(_units.remove(id)!.node);
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
  void useCamera(BattleCamera camera) {
    _insideUnit = camera.insideUnit;
    _hideInsideUnit();
  }

  /// The body the eye is inside would fill the view: it is not drawn.
  void _hideInsideUnit() {
    for (final MapEntry(:key, :value) in _units.entries) {
      value.node.visible = key != _insideUnit;
    }
  }

  @override
  void showShots(Iterable<ShotEffect> effects) {
    for (final shot in _shots.add(effects)) {
      final drawn = _shotNode(shot.effect);
      scene.add(drawn.node);
      _shotNodes[shot] = drawn;
    }
    _fadeShots();
  }

  @override
  void showPath(List<Position>? points) {
    if (_pathPoints == points) return;
    _pathPoints = points;
    _pathNodes
      ..forEach(scene.remove)
      ..clear();
    if (points == null) return;
    final material = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..doubleSided = true
      ..baseColorFactor = Vector4(0.35, 0.9, 1, 0.85);
    for (var i = 0; i + 1 < points.length; i++) {
      final start = _onGround(points[i])..y += 1.5;
      final end = _onGround(points[i + 1])..y += 1.5;
      final along = end - start;
      if (along.length == 0) continue;
      final z = along.normalized();
      final x = (z.y.abs() > 0.99 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)).cross(
        z,
      )..normalize();
      final y = z.cross(x);
      final mid = (start + end) / 2;
      final node = Node(
        mesh: Mesh(CuboidGeometry(Vector3(1.6, 0.6, along.length)), material),
        localTransform: Matrix4(
          x.x,
          x.y,
          x.z,
          0, //
          y.x,
          y.y,
          y.z,
          0,
          z.x,
          z.y,
          z.z,
          0,
          mid.x,
          mid.y,
          mid.z,
          1,
        ),
      );
      scene.add(node);
      _pathNodes.add(node);
    }
  }

  @override
  void tick(double seconds) {
    _clock += seconds;
    for (final glide in _units.values) {
      final at = glide.at(_clock);
      glide.node.localTransform = Matrix4.translation(at);
    }
    for (final shot in _shots.advance(seconds)) {
      scene.remove(_shotNodes.remove(shot)!.node);
    }
    _fadeShots();
  }

  /// Fades each shot on screen with its age, and swells its hit mark.
  void _fadeShots() {
    for (final MapEntry(key: shot, value: drawn) in _shotNodes.entries) {
      drawn.material.baseColorFactor = drawn.color.clone()..w = shot.opacity;
      if (shot.effect is HitMark) {
        drawn.node.localTransform = drawn.base.clone()
          ..scaleByDouble(
            1 + shot.progress,
            1 + shot.progress,
            1 + shot.progress,
            1,
          );
      }
    }
  }

  /// The muzzle of a unit drawn at [position]: units are drawn big.
  Vector3 _muzzle(Position position) => _onGround(position)..y += 6;

  _ShotNode _shotNode(ShotEffect effect) {
    final material = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..doubleSided = true;
    final (geometry, color, base) = switch (effect) {
      Tracer(:final from, :final to) => () {
        final start = _muzzle(from);
        final end = _muzzle(to);
        final along = end - start;
        final z = along.normalized();
        final x =
            (z.y.abs() > 0.99 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)).cross(z)
              ..normalize();
        final y = z.cross(x);
        final mid = (start + end) / 2;
        return (
          CuboidGeometry(Vector3(1.2, 1.2, along.length)) as Geometry,
          Vector4(1, 0.95, 0.5, 1),
          Matrix4(
            x.x,
            x.y,
            x.z,
            0, //
            y.x,
            y.y,
            y.z,
            0,
            z.x,
            z.y,
            z.z,
            0,
            mid.x,
            mid.y,
            mid.z,
            1,
          ),
        );
      }(),
      MuzzleFlash(:final at) => (
        SphereGeometry(radius: 3, segments: 12, rings: 6) as Geometry,
        Vector4(1, 0.85, 0.3, 1),
        Matrix4.translation(_muzzle(at)),
      ),
      HitMark(:final at, :final result) => (
        SphereGeometry(radius: 2.4, segments: 12, rings: 6) as Geometry,
        result == ImpactResult.damaged
            ? Vector4(1, 0.35, 0.1, 1)
            : Vector4(0.7, 0, 0, 1),
        Matrix4.translation(_onGround(at)..y += 3),
      ),
    };
    material.baseColorFactor = color.clone();
    return _ShotNode(
      Node(mesh: Mesh(geometry, material), localTransform: base.clone()),
      material,
      color,
      base,
    );
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

/// A shot effect's node, its material, and the colour and transform it
/// started with.
class _ShotNode {
  new(this.node, this.material, this.color, this.base);

  final Node node;
  final UnlitMaterial material;
  final Vector4 color;
  final Matrix4 base;
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
