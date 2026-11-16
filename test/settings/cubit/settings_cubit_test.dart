import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:battle_team/settings/data/player_settings_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/log_capture.dart';
import '../../helpers/settings.dart';

class _MockRepository extends Mock implements PlayerSettingsRepository;

void main() {
  setUpAll(() => registerFallbackValue(const PlayerSettings()));

  group(SettingsCubit, () {
    late PlayerSettingsRepository repository;

    setUp(() => repository = PlayerSettingsRepository(emptyPreferences()));

    test('starts with the defaults', () {
      expect(
        SettingsCubit(repository: repository).state,
        const PlayerSettings(),
      );
    });

    blocTest<SettingsCubit, PlayerSettings>(
      'turns the sound effects off and on, and keeps it',
      build: () => SettingsCubit(repository: repository),
      act: (cubit) async {
        await cubit.setSoundEffects(on: false);
        await cubit.setSoundEffects(on: true);
        await cubit.setSoundEffects(on: false);
      },
      expect: () => [
        const PlayerSettings(soundEffects: false),
        const PlayerSettings(),
        const PlayerSettings(soundEffects: false),
      ],
      verify: (_) async =>
          expect((await repository.load()).soundEffects, isFalse),
    );

    blocTest<SettingsCubit, PlayerSettings>(
      'turns the ambience music off, and keeps it',
      build: () => SettingsCubit(repository: repository),
      act: (cubit) => cubit.setAmbience(on: false),
      expect: () => [const PlayerSettings(ambience: false)],
      verify: (_) async => expect((await repository.load()).ambience, isFalse),
    );

    blocTest<SettingsCubit, PlayerSettings>(
      'puts a command on a key, swapping with the command that had it, and '
      'gives the default keys back',
      build: () => SettingsCubit(repository: repository),
      act: (cubit) async {
        await cubit.rebind(BattleCommand.turnLeft, LogicalKeyboardKey.keyE);
        await cubit.resetKeys();
      },
      expect: () => [
        PlayerSettings(
          keys: KeyBindings.defaults.rebind(
            BattleCommand.turnLeft,
            LogicalKeyboardKey.keyE,
          ),
        ),
        const PlayerSettings(),
      ],
    );

    test('takes what the player chose in an earlier run', () async {
      await repository.save(const PlayerSettings(ambience: false));
      final cubit = SettingsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const PlayerSettings(ambience: false));
    });

    group('with a device that cannot keep anything', () {
      late _MockRepository broken;
      late LogCapture log;

      setUp(() {
        broken = _MockRepository();
        when(broken.load).thenThrow(StateError('no storage'));
        when(() => broken.save(any())).thenThrow(StateError('no storage'));
        log = LogCapture();
        addTearDown(log.cancel);
      });

      test('plays with the defaults and says so', () async {
        final cubit = SettingsCubit(repository: broken);
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state, const PlayerSettings());
        expect(log.lines, contains('WARNING settings not loaded: StateError'));
      });

      test('a change still shows, and says it was not kept', () async {
        final cubit = SettingsCubit(repository: broken);
        addTearDown(cubit.close);

        await cubit.setAmbience(on: false);

        expect(cubit.state.ambience, isFalse);
        expect(log.lines, contains('WARNING settings not saved: StateError'));
      });

      test('loading after the cubit closed changes nothing', () async {
        final slow = _MockRepository();
        when(slow.load)
            .thenAnswer((_) async => const PlayerSettings(ambience: false));
        final cubit = SettingsCubit(repository: slow);

        final loading = cubit.load();
        await cubit.close();
        await loading;

        expect(cubit.state, const PlayerSettings());
      });
    });
  });
}
