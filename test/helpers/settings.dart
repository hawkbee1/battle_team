import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/player_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fresh in-memory store of the player's preferences, as the app has on a
/// device that kept nothing yet.
SharedPreferencesAsync emptyPreferences() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  return SharedPreferencesAsync();
}

/// A settings cubit over an in-memory store, with the default settings, closed
/// at the end of the test.
SettingsCubit realSettings() {
  final cubit = SettingsCubit(
    repository: PlayerSettingsRepository(emptyPreferences()),
  );
  addTearDown(cubit.close);
  return cubit;
}
