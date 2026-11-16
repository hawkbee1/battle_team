import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:battle_team/settings/data/player_settings_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// {@template settings_cubit}
/// The player's [PlayerSettings] for the whole app: the battle view reads its
/// keys, the sound reads its two switches, the settings page changes them.
/// Each change shows at once and is kept on the device after; a device that
/// cannot keep it (no storage) still plays with the change until the app
/// closes. It logs on `battle_team.SettingsCubit`, never a key.
/// {@endtemplate}
class SettingsCubit extends Cubit<PlayerSettings> {
  /// {@macro settings_cubit}
  new({required this.repository}) : super(const PlayerSettings());

  /// Where the settings are kept.
  final PlayerSettingsRepository repository;

  static final _log = Logger('battle_team.SettingsCubit');

  /// Takes what the player chose in an earlier run.
  Future<void> load() async {
    try {
      final settings = await repository.load();
      if (!isClosed) emit(settings);
    } on Object catch (error) {
      _log.warning('settings not loaded: ${error.runtimeType}');
    }
  }

  /// Turns the sound effects on or off.
  Future<void> setSoundEffects({required bool on}) =>
      _change(state.copyWith(soundEffects: on));

  /// Turns the ambience music on or off.
  Future<void> setAmbience({required bool on}) =>
      _change(state.copyWith(ambience: on));

  /// Puts [command] on [key]; the command that had [key] takes the key this
  /// one had.
  Future<void> rebind(BattleCommand command, LogicalKeyboardKey key) =>
      _change(state.copyWith(keys: state.keys.rebind(command, key)));

  /// Gives every command its default key back.
  Future<void> resetKeys() =>
      _change(state.copyWith(keys: KeyBindings.defaults));

  Future<void> _change(PlayerSettings settings) async {
    emit(settings);
    try {
      await repository.save(settings);
    } on Object catch (error) {
      _log.warning('settings not saved: ${error.runtimeType}');
    }
  }
}
