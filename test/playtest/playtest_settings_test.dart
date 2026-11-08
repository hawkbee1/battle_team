// Built at run time, so that coverage sees the constructors.
// ignore_for_file: prefer_const_constructors
import 'package:battle_team/playtest/playtest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PlaytestSettings, () {
    test('is complete with every setting', () {
      final settings = PlaytestSettings(
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
        PlaytestSettings(
          endpoint: 'http://localhost/v1',
          projectId: 'hawkbee',
          email: 'blue@battleteam.local',
          password: 'secret',
          battleId: 'pt-1',
        ),
      );
    });

    test('is not complete without its build settings', () {
      expect(PlaytestSettings.fromEnvironment().complete, isFalse);
    });
  });
}
