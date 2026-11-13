// coverage:ignore-file
// Draws through flutter_scene, which needs a GPU context that
// `flutter test` does not have.
//
// POC (branch poc/streamed-world).

import 'package:battle_team/battle/world/team_colours.dart';
import 'package:battle_team/battle/world/tree_model.dart';
import 'package:battle_team/battle/world/unit_levels.dart';
import 'package:battle_team/battle/world/unit_model.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// {@template unit_instances}
/// Draws the units as instances: one `InstancedMesh` per unit model, per
/// level and per part of the model, with one instance per unit, and one more
/// for the discs under them. A thousand units then cost the draws of the
/// models, whatever their number.
///
/// A unit within [nearM] of the eye is drawn with its near model, the others
/// with the far one (`unitLevelAt`).
///
/// Each unit shows its team three ways: its model, tinted in the team's
/// colour (the far one whole, the near one on some parts and mixed with
/// white: see `UnitShape.tint`), the disc under it in that colour, and a rim
/// around the disc, white or black, that stands out from the disc by
/// lightness, a cue that does not depend on a hue (`rimColor`).
/// {@endtemplate}
class UnitInstances {
  /// {@macro unit_instances}
  new({required this.scene, required this.models, this.nearM = 100});

  /// The scene the meshes are added to.
  final Scene scene;

  /// The models of the units.
  final UnitModels models;

  /// How far from the eye a unit is drawn with its near model, in metres.
  final double nearM;

  /// The share of a disc's radius that its rim takes, on the outside.
  static const _rimShare = 0.2;

  final _units = <String, _Unit>{};
  final _batches = <UnitShape, _Batch>{};

  /// The disc in the team's colour and the rim around it, side by side: a
  /// unit's disc is `discM` metres in radius with both.
  late final _Batch _discs = _Batch(scene, 'unit_discs', [
    (
      geometry: DiscGeometry(radius: 1 - _rimShare, segments: 24),
      material: UnlitMaterial()..doubleSided = true,
      transform: Matrix4.identity(),
    ),
    (
      geometry: RingGeometry(
        innerRadius: 1 - _rimShare,
        outerRadius: 1,
        segments: 24,
      ),
      material: UnlitMaterial()..doubleSided = true,
      transform: Matrix4.identity(),
    ),
  ], (team, part) => part == 0 ? team : rimColor(team));
  final _base = Matrix4.identity();
  final _turn = Quaternion.identity();
  final _scale = Vector3.all(1);
  final _up = Vector3(0, 1, 0);

  /// The units drawn with their near model and with their far model, and
  /// the instanced meshes that draw them all: for a debug overlay.
  ({int near, int far, int meshes}) get counts {
    var near = 0;
    var far = 0;
    for (final unit in _units.values) {
      if (unit.shape == null) continue;
      unit.level == .near ? near++ : far++;
    }
    return (
      near: near,
      far: far,
      meshes: [
        _discs,
        ..._batches.values,
      ].fold(0, (sum, batch) => sum + (batch.isEmpty ? 0 : batch.meshes)),
    );
  }

  /// Draws the unit [id] of [unitType] standing at [at] and facing [yaw]
  /// (radians around +Y from +Z), seen from [eye], in its team's [color]
  /// (linear RGB, `teamColor`), on a disc of [discM] metres. Call it again
  /// when any of these changes: it does nothing for a unit that did not move
  /// nor change colour. A [hidden] unit is not drawn.
  void place(
    String id, {
    required String unitType,
    required Vector4 color,
    required Vector3 at,
    required double yaw,
    required Vector3? eye,
    double discM = 3,
    bool hidden = false,
  }) {
    final unit = _units[id] ??= _Unit();
    final model = models.of(unitType);
    final level = eye == null
        ? UnitLevel.far
        : unitLevelAt(at.distanceTo(eye), now: unit.level, nearM: nearM);
    final shape = hidden ? null : model?[level];
    final disc = hidden ? null : discM;
    final moved = unit.at != at || unit.yaw != yaw;
    final recoloured = unit.color != color;
    unit
      ..at.setFrom(at)
      ..yaw = yaw
      ..level = level;
    if (!identical(shape, unit.shape)) {
      _leave(id, unit.shape);
      unit.shape = shape;
      if (shape != null) {
        (_batches[shape] ??= _Batch(
          scene,
          'units_${unitType}_${level.name}',
          shape.parts,
          (team, part) => shape.tint[part] == 0
              ? null
              : mixedWithWhite(team, shape.tint[part]),
        )).add(id, _baseOf(unit), color);
      }
    } else if (shape != null) {
      if (moved) _batches[shape]!.move(id, _baseOf(unit));
      if (recoloured) _batches[shape]!.colour(id, color);
    }
    unit.color.setFrom(color);
    if (disc != unit.discM) {
      if (unit.discM != null) _leaveDiscs(id);
      unit.discM = disc;
      if (disc != null) _discs.add(id, _discOf(unit), color);
    } else if (disc != null) {
      if (moved) _discs.move(id, _discOf(unit));
      if (recoloured) _discs.colour(id, color);
    }
  }

  /// Stops drawing the unit [id].
  void remove(String id) {
    final unit = _units.remove(id);
    if (unit == null) return;
    _leave(id, unit.shape);
    if (unit.discM != null) _leaveDiscs(id);
  }

  void _leave(String id, UnitShape? shape) {
    if (shape == null) return;
    // The instance that took the place of the one removed is written again.
    final moved = _batches[shape]!.remove(id);
    if (moved == null) return;
    final unit = _units[moved]!;
    _batches[shape]!
      ..move(moved, _baseOf(unit))
      ..colour(moved, unit.color);
  }

  void _leaveDiscs(String id) {
    final moved = _discs.remove(id);
    if (moved == null) return;
    final unit = _units[moved]!;
    _discs
      ..move(moved, _discOf(unit))
      ..colour(moved, unit.color);
  }

  /// From the unit's frame to the world. The matrix is reused: read it
  /// before the next call.
  Matrix4 _baseOf(_Unit unit) {
    _turn.setAxisAngle(_up, unit.yaw);
    return _base..setFromTranslationRotationScale(unit.at, _turn, _scale);
  }

  /// The disc under the unit, just above the ground.
  Matrix4 _discOf(_Unit unit) {
    final size = unit.discM!;
    return _base
      ..setIdentity()
      ..setTranslationRaw(unit.at.x, unit.at.y + 0.3, unit.at.z)
      ..scaleByDouble(size, 1, size, 1);
  }
}

/// What is drawn of a unit now.
class _Unit {
  final Vector3 at = Vector3.all(double.nan);
  final Vector4 color = Vector4.zero();
  double yaw = 0;
  UnitLevel? level;

  /// The shape it has an instance of, null when it has none.
  UnitShape? shape;

  /// The size of its disc, null when it has none.
  double? discM;
}

/// The colour of one part of an instance, from its team's colour, or null to
/// leave the part as it is.
typedef _Paint = Vector4? Function(Vector4 team, int part);

/// The instances of one set of parts: an instanced mesh per part, and which
/// instance is which unit's.
class _Batch {
  new(Scene scene, String name, this.parts, this.paint)
    : _meshes = [
        for (final part in parts)
          InstancedMesh(geometry: part.geometry, material: part.material),
      ] {
    final node = Node(name: name);
    for (final mesh in _meshes) {
      node.add(Node()..addComponent(InstancedMeshComponent(mesh)));
    }
    scene.add(node);
  }

  final List<TreePart> parts;
  final _Paint paint;
  final List<InstancedMesh> _meshes;
  final _slots = InstanceSlots<String>();
  final _scratch = Matrix4.identity();

  int get meshes => _meshes.length;

  bool get isEmpty => _slots.length == 0;

  void add(String id, Matrix4 base, Vector4 team) {
    _slots.add(id);
    for (final (index, mesh) in _meshes.indexed) {
      mesh.addInstance(_at(base, index), color: paint(team, index));
    }
  }

  void move(String id, Matrix4 base) {
    final slot = _slots.indexOf(id)!;
    for (final (index, mesh) in _meshes.indexed) {
      mesh.setInstanceTransform(slot, _at(base, index));
    }
  }

  void colour(String id, Vector4 team) {
    final slot = _slots.indexOf(id)!;
    for (final (index, mesh) in _meshes.indexed) {
      // A part left as it is never had a colour of its own.
      if (paint(team, index) case final color?) {
        mesh.setInstanceColor(slot, color);
      }
    }
  }

  /// Removes the instance of [id] and returns the unit whose instance took
  /// its index and still holds [id]'s transform and colour, if any.
  String? remove(String id) {
    final freed = _slots.remove(id);
    if (freed == null) return null;
    for (final mesh in _meshes) {
      mesh.removeInstanceAt(freed.last);
    }
    return freed.index == freed.last ? null : _slots.keyAt(freed.index);
  }

  Matrix4 _at(Matrix4 base, int part) => _scratch
    ..setFrom(base)
    ..multiply(parts[part].transform);
}
