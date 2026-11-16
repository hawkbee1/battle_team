import 'dart:async';

import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/sounds/battle_audio.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:battle_team/battle/sounds/sound_listener.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/settings.dart';

class _MockWorld extends Mock implements BattleWorld;

class _MockBattleCubit extends MockCubit<BattleState> implements BattleCubit;

class _FakeAudio implements BattleAudio {
  final List<SoundCue> played = [];
  final List<bool> ambience = [];
  bool disposed = false;

  @override
  void play(Iterable<SoundCue> cues) => played.addAll(cues);

  @override
  void setAmbience({required bool on}) => ambience.add(on);

  @override
  void dispose() => disposed = true;
}

void main() {
  group(SoundListener, () {
    late _MockBattleCubit cubit;
    late SettingsCubit settings;
    late StreamController<List<SoundCue>> sounds;
    late List<_FakeAudio> audios;

    setUp(() {
      cubit = _MockBattleCubit();
      settings = realSettings();
      sounds = StreamController<List<SoundCue>>.broadcast(sync: true);
      audios = [];
      when(() => cubit.sounds).thenAnswer((_) => sounds.stream);
    });

    tearDown(() => sounds.close());

    Widget app(BattleWorld world) => MultiBlocProvider(
      providers: [
        BlocProvider<BattleCubit>.value(value: cubit),
        BlocProvider<SettingsCubit>.value(value: settings),
      ],
      child: SoundListener(
        world: world,
        audioBuilder: (_) {
          final audio = _FakeAudio();
          audios.add(audio);
          return audio;
        },
        child: const Text('battle', textDirection: TextDirection.ltr),
      ),
    );

    testWidgets('M7.14 shows its child and plays what the cubit announces', (
      tester,
    ) async {
      await tester.pumpWidget(app(_MockWorld()));

      sounds.add(const [
        SoundCue(Sound.shot, subject: 'rifle'),
        SoundCue(Sound.death),
      ]);

      expect(find.text('battle'), findsOneWidget);
      expect(audios.single.played, const [
        SoundCue(Sound.shot, subject: 'rifle'),
        SoundCue(Sound.death),
      ]);
    });

    testWidgets('M7.14 lets go of the audio and stops listening when it goes', (
      tester,
    ) async {
      await tester.pumpWidget(app(_MockWorld()));
      final audio = audios.single;

      await tester.pumpWidget(const SizedBox());
      sounds.add(const [SoundCue(Sound.death)]);

      expect(audio.disposed, isTrue);
      expect(audio.played, isEmpty);
    });

    testWidgets('M7.14 a new world gets a new audio, the old one let go', (
      tester,
    ) async {
      final world = _MockWorld();
      await tester.pumpWidget(app(world));
      await tester.pumpWidget(app(world));
      expect(audios, hasLength(1));

      await tester.pumpWidget(app(_MockWorld()));
      sounds.add(const [SoundCue(Sound.victory)]);

      expect(audios, hasLength(2));
      expect(audios.first.disposed, isTrue);
      expect(audios.last.played, const [SoundCue(Sound.victory)]);
      // The new audio starts as the settings say.
      expect(audios.last.ambience, [true]);
    });

    testWidgets('plays nothing while the sound effects are off, and plays '
        'again when they are back', (tester) async {
      await tester.pumpWidget(app(_MockWorld()));

      await settings.setSoundEffects(on: false);
      sounds.add(const [SoundCue(Sound.shot)]);
      expect(audios.single.played, isEmpty);

      await settings.setSoundEffects(on: true);
      sounds.add(const [SoundCue(Sound.death)]);
      expect(audios.single.played, const [SoundCue(Sound.death)]);
    });

    testWidgets('starts the ambience as the settings say, and follows them', (
      tester,
    ) async {
      await settings.setAmbience(on: false);
      await tester.pumpWidget(app(_MockWorld()));
      final audio = audios.single;
      expect(audio.ambience, [false]);

      await settings.setAmbience(on: true);
      await tester.pump();
      await settings.setAmbience(on: false);
      await tester.pump();

      expect(audio.ambience, [false, true, false]);
    });

    testWidgets('the ambience does not restart when only the sound effects '
        'change', (tester) async {
      await tester.pumpWidget(app(_MockWorld()));

      await settings.setSoundEffects(on: false);
      await tester.pump();

      expect(audios.single.ambience, [true]);
    });
  });
}
