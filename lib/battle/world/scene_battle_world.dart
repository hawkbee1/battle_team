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
import 'package:battle_team/battle/world/glide.dart';
import 'package:battle_team/battle/world/ground_material.dart';
import 'package:battle_team/battle/world/ground_streamer.dart';
import 'package:battle_team/battle/world/live_shots.dart';
import 'package:battle_team/battle/world/map_edge.dart';
import 'package:battle_team/battle/world/team_colours.dart';
import 'package:battle_team/battle/world/tree_model.dart';
import 'package:battle_team/battle/world/unit_instances.dart';
import 'package:battle_team/battle/world/unit_model.dart';
import 'package:battle_team/battle/world/unit_routes.dart';
import 'package:battle_team/battle/world/weather_look.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// {@template scene_battle_world}
/// The battle in 3D with flutter_scene, the renderer behind the `BattleWorld`
/// Strategy: the map's ground, its trees and buildings, and what the section
/// sees (units, HQs, relics), each unit gliding to where the host put it by
/// its move's arrival time (decision 236) along the way [routes] plans, on
/// the ground and over the bridges' decks, and the shots it sees for a
/// moment each (`LiveShots` keeps their lives; this class only draws them).
/// Units are drawn at their size, as instances of their models (POC: see
/// `UnitInstances`), each tinted in its team's colour (`teamColor`) and on a
/// disc with a rim that show from above. Cliffs climb around the map on its
/// four sides, under a sky and a far haze of the battle's weather.
/// {@endtemplate}
class SceneBattleWorld implements BattleWorld {
  /// {@macro scene_battle_world}
  new(this.map, this.trees, this.unitModels, this.ground, this.routes)
    : surface = TerrainSurface(map);

  /// The map.
  final MapData map;

  /// The tree models the trees of the map are drawn with.
  final List<TreeModel> trees;

  /// The models the units are drawn with.
  final UnitModels unitModels;

  /// The materials the ground is drawn with, and their textures.
  final GroundMaterials ground;

  /// The ways moving units are drawn going.
  final UnitRoutes routes;

  @override
  final TerrainSurface surface;

  /// The scene, built on first use: read it only once
  /// `Scene.initializeStaticResources()` completed.
  late final Scene scene = Scene();

  final _units = <String, _Unit>{};
  final _hqs = <String, (Node, String?)>{};
  final _relics = <String, (Node, String?)>{};
  final _shots = LiveShots();
  final _shotNodes = <LiveShot, _ShotNode>{};
  final _pathNodes = <Node>[];
  List<Position>? _pathPoints;
  double _clock = 0;
  String? _insideUnit;
  BattleCamera? _camera;
  String? _selected;
  String? _target;
  late final UnitInstances _instances = UnitInstances(
    scene: scene,
    models: unitModels,
  );
  late final Node _selectedMark = _mark(Vector4(1, 1, 0.3, 1))..also(scene.add);
  late final Node _targetMark = _mark(Vector4(1, 1, 1, 1))..also(scene.add);

  @override
  Map<String, Vector3> get drawn => {
    for (final MapEntry(:key, :value) in _units.entries) key: _drawnAt(value),
  };

  /// Where [unit] is drawn now: on its route, at the height of what it
  /// stands on there.
  Vector3 _drawnAt(_Unit unit) {
    final at = unit.glide.at(_clock);
    return at..y = surface.heightAt(at.x, -at.z);
  }

  /// The points [unit] goes through from where it is drawn, [from], to
  /// [to], both included: by the path from the host's last position of it,
  /// [was], to its new one. A move the player confirmed was searched from
  /// and to the same cells by its preview, whose answer the planner keeps:
  /// the start of the glide does not search it again.
  List<Vector3> _route(UnitView unit, Position was, Vector3 from, Vector3 to) {
    final points = routes.route(
      unitType: unit.unitType,
      flying: unit.flying,
      from: was,
      to: unit.position!,
    );
    return [
      from,
      for (final point in points.sublist(1, points.length - 1))
        _onGround(point),
      to,
    ];
  }

  /// The ground, the trees and the buildings, as much of them as the eye
  /// needs (POC: see `GroundStreamer`).
  late final GroundStreamer _streamer = GroundStreamer(
    scene: scene,
    map: map,
    surface: surface,
    trees: trees,
    ground: ground,
  );

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
      // Only units with a position are spread.
      final position = unit.position!;
      final drawn = _units[unit.unitId] ??= _Unit(
        unit.unitType,
        teamColor(unit.team),
        Glide(to),
        position,
      );
      if (drawn.glide.to != to) {
        final until = unit.private?.movingUntil;
        final seconds = until != null && battleTime != null
            ? math.max(0, (until - battleTime).inMilliseconds / 1000)
            : 0.5;
        drawn.glide.retarget(
          _route(unit, drawn.at, _drawnAt(drawn), to),
          now: _clock,
          seconds: seconds.toDouble(),
        );
      }
      drawn.at = position;
    }
    _selected = selected;
    _target = target;
    for (final id in _units.keys.toList()) {
      if (!spread.containsKey(id)) {
        _units.remove(id);
        _instances.remove(id);
      }
    }
    _place(_hqs, {
      for (final hq in hqs) hq.team: (hq.position, hq.team),
    }, (team) => _hq(teamColor(team)));
    _place(_relics, {
      for (final relic in relics) relic.relicId: (relic.position, relic.owner),
    }, (owner) => _pillar(teamColor(owner)));
    tick(0);
  }

  @override
  void useCamera(BattleCamera camera) {
    _camera = camera;
    _insideUnit = camera.insideUnit;
    _addEdge();
  }

  bool _edgeAdded = false;

  /// Adds the cliffs around the map to the scene, the first time.
  void _addEdge() {
    if (_edgeAdded) return;
    _edgeAdded = true;
    final material = PhysicallyBasedMaterial()
      ..roughnessFactor = 0.95
      ..doubleSided = true;
    final node = Node(name: 'map_edge');
    for (final side in edgeCliffArrays(map)) {
      node.add(
        Node(
          mesh: Mesh(
            MeshGeometry.fromArrays(
              positions: side.positions,
              normals: side.normals,
              colors: side.colors,
              indices: side.indices,
            ),
            material,
          ),
        ),
      );
    }
    scene.add(node);
  }

  late final GradientSkySource _sky = GradientSkySource(
    // The sun where the ground's shading puts the light: high in the
    // north-west.
    sunDirection: Vector3(-1, 2, 1),
  );

  @override
  void showWeather(String? weather) {
    final look = weatherLookOf(weather);
    _sky
      ..zenithColor = vectorOf(look.zenith)
      ..horizonColor = vectorOf(look.horizon)
      ..groundColor = vectorOf(look.below)
      ..sunColor = vectorOf(look.sun);
    scene.skybox ??= Skybox(_sky);
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..color = vectorOf(look.haze)
      ..start = WeatherLook.hazeStartM
      ..density = look.hazeDensity;
    _streamer.showHaze(look);
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

  /// The fog on the ground: a texture of each page the fog changes is
  /// uploaded when it changes, never per frame (stack decision 4).
  @override
  void showFog(FogModel fog) => _streamer.showFog(fog);

  @override
  void tick(double seconds) {
    _clock += seconds;
    if (_camera case final camera?) _streamer.update(camera);
    final eye = _camera?.position;
    for (final MapEntry(key: id, value: unit) in _units.entries) {
      _instances.place(
        id,
        unitType: unit.unitType,
        color: unit.color,
        at: _drawnAt(unit),
        yaw: unit.glide.yawAt(_clock),
        eye: eye,
        // The body the eye is inside would fill the view: it is not drawn.
        hidden: id == _insideUnit,
      );
    }
    _placeMark(_selectedMark, _selected);
    _placeMark(_targetMark, _target);
    for (final shot in _shots.advance(seconds)) {
      scene.remove(_shotNodes.remove(shot)!.node);
    }
    _fadeShots();
  }

  /// Puts [mark] under the unit [id], or hides it when that unit is not
  /// drawn.
  void _placeMark(Node mark, String? id) {
    final unit = id == _insideUnit ? null : _units[id];
    mark.visible = unit != null;
    if (unit == null) return;
    mark.localTransform = Matrix4.translation(_drawnAt(unit)..y += 0.35);
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

  /// The muzzle of a unit drawn at [position].
  Vector3 _muzzle(Position position) => _onGround(position)..y += 1.6;

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
        Matrix4.translation(_onGround(at)..y += 1.2),
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

  /// Puts the nodes of [wanted] on the ground, each made by [make] for its
  /// team (`teamColor`) and made again when the team changes, a relic taken.
  void _place(
    Map<String, (Node, String?)> placed,
    Map<String, (Position, String?)> wanted,
    Node Function(String? team) make,
  ) {
    for (final id in placed.keys.toList()) {
      if (!wanted.containsKey(id)) scene.remove(placed.remove(id)!.$1);
    }
    for (final MapEntry(key: id, value: (position, team)) in wanted.entries) {
      var entry = placed[id];
      if (entry == null || entry.$2 != team) {
        if (entry != null) scene.remove(entry.$1);
        entry = (make(team)..also(scene.add), team);
        placed[id] = entry;
      }
      entry.$1.localTransform = Matrix4.translation(_onGround(position));
    }
  }

  /// A ring around a unit's disc, for the selected unit and for the target.
  static Node _mark(Vector4 color) => Node(
    mesh: Mesh(
      RingGeometry(innerRadius: 3.3, outerRadius: 4.2),
      UnlitMaterial()
        ..baseColorFactor = color
        ..doubleSided = true,
    ),
  )..visible = false;

  /// An HQ: its building, in the model's own colours, and what shows its
  /// team: a ring on the ground around it and a flag on a pole.
  Node _hq(Vector4 color) {
    final node = _flag(color);
    for (final part in unitModels.hq ?? const <TreePart>[]) {
      node.add(
        Node(
          mesh: Mesh(part.geometry, part.material),
          localTransform: part.transform,
        ),
      );
    }
    return node;
  }

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

/// A unit drawn: its type, its team's colour, its glide, and where the host
/// had it last.
class _Unit {
  new(this.unitType, this.color, this.glide, this.at);

  final String unitType;
  final Vector4 color;
  final Glide glide;
  Position at;
}

extension<T> on T {
  /// Calls [use] with this, then gives it back.
  T also(void Function(T) use) {
    use(this);
    return this;
  }
}
