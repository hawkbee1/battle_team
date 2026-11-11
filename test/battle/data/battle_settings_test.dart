// Built at run time, so that coverage sees the constructors.
// ignore_for_file: prefer_const_constructors
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(BattleSettings, () {
    test('M7.1 holds where one battle is played, on the first map', () {
      final settings = BattleSettings(
        endpoint: 'http://localhost/v1',
        projectId: 'hawkbee',
        battleId: 'pt-1',
      );

      expect(settings.mapId, 'saint_lo_1km');
      expect(
        settings,
        BattleSettings(
          endpoint: 'http://localhost/v1',
          projectId: 'hawkbee',
          battleId: 'pt-1',
        ),
      );
    });
  });

  group(PlaytestSettings, () {
    test('M7.12 is complete with every setting', () {
      final settings = PlaytestSettings(
        email: 'blue@battleteam.local',
        password: 'secret',
        battleId: 'pt-1',
      );

      expect(settings.complete, isTrue);
      expect(settings.mapId, 'saint_lo_1km');
      expect(
        settings,
        PlaytestSettings(
          email: 'blue@battleteam.local',
          password: 'secret',
          battleId: 'pt-1',
        ),
      );
    });

    test('M7.12 is not complete without its build settings', () {
      expect(PlaytestSettings.fromEnvironment().complete, isFalse);
    });

    test('M7.12 prints neither the email nor the password', () {
      final text = PlaytestSettings(
        email: 'blue@battleteam.local',
        password: 'secret-value',
        battleId: 'pt-1',
      ).toString();

      expect(text, isNot(contains('secret-value')));
      expect(text, isNot(contains('blue@battleteam.local')));
    });
  });
}
