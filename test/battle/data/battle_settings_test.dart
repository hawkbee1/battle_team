// Built at run time, so that coverage sees the constructors.
// ignore_for_file: prefer_const_constructors
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(BattleSettings, () {
    test('is complete with every setting', () {
      final settings = BattleSettings(
        endpoint: 'http://localhost/v1',
        projectId: 'hawkbee',
        email: 'blue@battleteam.local',
        password: 'secret',
        battleId: 'pt-1',
      );

      expect(settings.complete, isTrue);
      expect(settings.mapId, 'saint_lo_1km');
      expect(
        settings,
        BattleSettings(
          endpoint: 'http://localhost/v1',
          projectId: 'hawkbee',
          email: 'blue@battleteam.local',
          password: 'secret',
          battleId: 'pt-1',
        ),
      );
    });

    test('is not complete without its build settings', () {
      expect(BattleSettings.fromEnvironment().complete, isFalse);
    });
  });
}
