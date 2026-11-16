import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:battle_team/settings/data/player_settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/settings.dart';

void main() {
  group(PlayerSettingsRepository, () {
    late SharedPreferencesAsync preferences;
    late PlayerSettingsRepository repository;

    setUp(() {
      preferences = emptyPreferences();
      repository = PlayerSettingsRepository(preferences);
    });

    test(
      'has the defaults when nothing was kept: sounds on, default keys',
      () async {
        final settings = await repository.load();

        expect(settings, const PlayerSettings());
        expect(settings.soundEffects, isTrue);
        expect(settings.ambience, isTrue);
        expect(settings.keys, KeyBindings.defaults);
      },
    );

    test('gives back what it kept', () async {
      final chosen = PlayerSettings(
        soundEffects: false,
        ambience: false,
        keys: KeyBindings.defaults.rebind(
          BattleCommand.turnLeft,
          LogicalKeyboardKey.keyA,
        ),
      );

      await repository.save(chosen);

      expect(await repository.load(), chosen);
      // A repository over the same store, as after a restart.
      expect(await PlayerSettingsRepository(preferences).load(), chosen);
    });

    test('takes the default for a key this keyboard does not know', () async {
      await preferences.setInt('key_turnLeft', 0x1fffffffff);

      final settings = await repository.load();

      expect(
        settings.keys.keyOf(BattleCommand.turnLeft),
        LogicalKeyboardKey.keyQ,
      );
    });

    test('takes the default keys when two commands share one', () async {
      await preferences.setInt('key_turnLeft', LogicalKeyboardKey.keyE.keyId);

      final settings = await repository.load();

      expect(settings.keys, KeyBindings.defaults);
    });
  });
}
