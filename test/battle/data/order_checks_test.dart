import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/order_checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadOrderPreCheck', () {
    test(
      'M7.5 reads the weapons, the unit types and the storage numbers',
      () async {
        final check = await loadOrderPreCheck(rootBundle);

        // The plan's own files, not copies of their numbers (decision 3).
        expect(check.weaponType('rifle')?.rangeM, 400);
        expect(check.units.unitTypes, contains('soldier'));
        expect(check.storeRadiusM, 10);
        expect(check.storage.recallS, 21600);
        expect(check.storage.deployAp, 10);
        expect(check.storage.deployBlockRadiusM, 20);
        expect(check, isA<OrderPreCheck>());
      },
    );
  });

  group('loadMovePreview', () {
    test('M7.8 builds the navigation model of the bundled map: a soldier '
        'on it plans a path and prices it with the plan terrain', () async {
      final previewer = await loadMovePreview(rootBundle, 'saint_lo_1km');

      final plan = previewer.preview(
        unit: blueCommander,
        destination: const Position(53500, 5500, 3000),
        seen: const [],
        time: const Duration(hours: 1),
      );

      expect(plan, isA<MovePreview>());
      final move = plan as MovePreview;
      // The commander's cell is the first of the path, the destination's the
      // last: 30 m east on a 10 m grid.
      expect(move.cells.first, const Cell(50, 5));
      expect(move.cells.last, const Cell(53, 5));
      expect(move.lengthM, closeTo(30, 1e-6));
      expect(move.costAp, greaterThan(0));
      expect(move.points.first.x, closeTo(505, 1e-6));
    });

    test('M7.8 a destination off the map is refused', () async {
      final previewer = await loadMovePreview(rootBundle, 'saint_lo_1km');

      expect(
        previewer.preview(
          unit: blueCommander,
          destination: const Position(-1000, 5500, 3000),
          seen: const [],
          time: const Duration(hours: 1),
        ),
        const MoveRefused(PreCheckRefusal.offMap),
      );
    });
  });
}
