import 'dart:io';

import 'package:battle_rules/battle_rules.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(UnitBodies, () {
    late UnitsData units;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      units = UnitsData.parse(File('plan/data/units.yaml').readAsStringSync());
    });

    test('decision 235 gives the hit box height of each unit type', () {
      final bodies = UnitBodies.fromUnits(units);

      for (final MapEntry(key: id, value: type) in units.unitTypes.entries) {
        expect(bodies.eyeHeightOf(id), type.hitBox.height, reason: id);
      }
    });

    test('M7.4 knows no body for a type the data does not name', () {
      expect(UnitBodies.fromUnits(units).eyeHeightOf('no_such_unit'), isNull);
    });

    test('M7.4 loads the plan file the app bundles', () async {
      final bodies = await loadUnitBodies(rootBundle);

      expect(unitsAsset, 'plan/data/units.yaml');
      for (final MapEntry(key: id, value: type) in units.unitTypes.entries) {
        expect(bodies.eyeHeightOf(id), type.hitBox.height, reason: id);
      }
    });
  });
}
