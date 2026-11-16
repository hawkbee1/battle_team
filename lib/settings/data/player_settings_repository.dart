import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template player_settings_repository}
/// Keeps the player's [PlayerSettings] on the device, in the platform's
/// preferences (the browser's local storage on the web). The cubit above it
/// never sees the preferences (Adapter). What is missing or no longer valid
/// (a key this keyboard does not know, two commands on one key) is the
/// default.
/// {@endtemplate}
class PlayerSettingsRepository {
  /// {@macro player_settings_repository}
  const new(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _soundEffects = 'sound_effects';
  static const _ambience = 'ambience';
  static String _keyOf(BattleCommand command) => 'key_${command.name}';

  /// What the player chose before, or the defaults.
  Future<PlayerSettings> load() async {
    final bindings = KeyBindings({
      for (final command in BattleCommand.values)
        if (await _preferences.getInt(_keyOf(command)) case final id?)
          command: ?LogicalKeyboardKey.findKeyByKeyId(id),
    });
    return PlayerSettings(
      soundEffects: await _preferences.getBool(_soundEffects) ?? true,
      ambience: await _preferences.getBool(_ambience) ?? true,
      keys: bindings.isValid ? bindings : KeyBindings.defaults,
    );
  }

  /// Keeps [settings].
  Future<void> save(PlayerSettings settings) async {
    await _preferences.setBool(_soundEffects, settings.soundEffects);
    await _preferences.setBool(_ambience, settings.ambience);
    for (final command in BattleCommand.values) {
      await _preferences.setInt(
        _keyOf(command),
        settings.keys.keyOf(command).keyId,
      );
    }
  }
}
