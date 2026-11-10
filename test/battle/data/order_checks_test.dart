import 'package:battle_client/battle_client.dart';
import 'package:battle_team/battle/data/order_checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
