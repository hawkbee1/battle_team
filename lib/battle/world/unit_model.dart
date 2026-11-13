// coverage:ignore-file
// Imports the glTF models through flutter_scene, which needs a GPU context
// that `flutter test` does not have.
//
// POC (branch poc/streamed-world).

import 'dart:math' as math;

import 'package:battle_team/battle/world/tree_model.dart';
import 'package:battle_team/battle/world/unit_levels.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:vector_math/vector_math.dart';

/// A kind of unit model: where its near and far models are in the app's
/// assets, and how they stand in the game. The models keep the scale and
/// the frame of their download, so each is brought to `sizeM` metres, its
/// height or (when `byLength`) the longer side of its footprint, and turned
/// by `frontYaw` radians around +Y so that its front is on +Z.
typedef UnitKind = ({
  String near,
  String far,
  double sizeM,
  bool byLength,
  double frontYaw,
});

/// Every infantry unit, for now: the soldier, 1.8 m tall.
const UnitKind infantryKind = (
  near: 'assets/3d_models/infantry_near.glb',
  far: 'assets/3d_models/infantry_far.glb',
  sizeM: 1.8,
  byLength: false,
  frontYaw: math.pi,
);

/// Every vehicle, for now: the tank, 5.85 m long. Its model is longer on X
/// than on Z, so it is turned a quarter.
const UnitKind vehicleKind = (
  near: 'assets/3d_models/vehicle_near.glb',
  far: 'assets/3d_models/vehicle_far.glb',
  sizeM: 5.85,
  byLength: true,
  frontYaw: math.pi / 2,
);

/// The unit types drawn with the vehicle's model; the others take the
/// infantry's.
const vehicleUnitTypes = {'jeep', 'tank', 'truck', 'artillery'};

/// {@template unit_shape}
/// A unit model at one level, flattened into its parts. The transform of
/// each part goes from the part to the unit's frame: metres, the feet on
/// the origin, the front on +Z.
/// {@endtemplate}
typedef UnitShape = List<TreePart>;

/// {@template unit_models}
/// The models units are drawn with, each at its two levels. A kind left out
/// (in tests, which have no GPU) draws nothing but the disc under the unit.
/// {@endtemplate}
final class UnitModels {
  /// {@macro unit_models}
  const new({this.infantry, this.vehicle});

  /// The model of infantry units.
  final Map<UnitLevel, UnitShape>? infantry;

  /// The model of vehicles.
  final Map<UnitLevel, UnitShape>? vehicle;

  /// The model of a unit of [unitType].
  Map<UnitLevel, UnitShape>? of(String unitType) =>
      vehicleUnitTypes.contains(unitType) ? vehicle : infantry;
}

/// Loads the unit models from the app's assets.
Future<UnitModels> loadUnitModels(AssetBundle bundle) async => UnitModels(
  infantry: await _loadKind(infantryKind),
  vehicle: await _loadKind(vehicleKind),
);

Future<Map<UnitLevel, UnitShape>> _loadKind(UnitKind kind) async => {
  .near: await _loadShape(kind.near, kind),
  .far: await _loadShape(kind.far, kind),
};

/// Each level is fitted by its own box: lightening a model moves its box a
/// little, and both must stand on the ground.
Future<UnitShape> _loadShape(String asset, UnitKind kind) async {
  final (:parts, :min, :max) = await loadModelParts(asset);
  if (!min.x.isFinite) return parts;
  final size = kind.byLength
      ? math.max(max.x - min.x, max.z - min.z)
      : max.y - min.y;
  final fit =
      Matrix4.compose(
        Vector3.zero(),
        Quaternion.axisAngle(Vector3(0, 1, 0), kind.frontYaw),
        Vector3.all(size > 0 ? kind.sizeM / size : 1),
      )..translateByVector3(
        Vector3(-(min.x + max.x) / 2, -min.y, -(min.z + max.z) / 2),
      );
  return [
    for (final part in parts)
      (
        geometry: part.geometry,
        material: part.material,
        transform: fit.multiplied(part.transform),
      ),
  ];
}
