import 'package:battle_rules/battle_rules.dart';
import 'package:flutter/services.dart';

/// Where the unit types' data is in the app's assets: the plan's own file.
const unitsAsset = 'plan/data/units.yaml';

/// {@template unit_bodies}
/// The bodies of the unit types, from `hit_box_m` of `units.yaml`: what the
/// first-person camera needs of a unit. The eye sits at the top of the hit
/// volume, the height a sight line starts from (decision 235). The app reads
/// the value and computes no rule with it (decision 3).
/// {@endtemplate}
class UnitBodies {
  /// {@macro unit_bodies}
  const new(this._heights);

  /// The bodies of every unit type of [units].
  factory fromUnits(UnitsData units) => UnitBodies({
    for (final MapEntry(:key, :value) in units.unitTypes.entries)
      key: value.hitBox.height,
  });

  final Map<String, double> _heights;

  /// The height of a [unitType]'s hit volume, in metres, which is where its
  /// eyes are; null for a type the data does not know.
  double? eyeHeightOf(String unitType) => _heights[unitType];
}

/// The unit types' bodies from the app's assets.
///
/// Throws a `GameDataException` for a file out of the format.
Future<UnitBodies> loadUnitBodies(AssetBundle bundle) async =>
    UnitBodies.fromUnits(UnitsData.parse(await bundle.loadString(unitsAsset)));
