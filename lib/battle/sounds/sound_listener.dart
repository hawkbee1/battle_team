import 'dart:async';

import 'package:battle_team/battle/cubit/battle_cubit.dart';
import 'package:battle_team/battle/sounds/battle_audio.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:battle_team/battle/world/battle_world.dart';
import 'package:battle_team/settings/cubit/settings_cubit.dart';
import 'package:battle_team/settings/data/player_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template sound_listener}
/// Plays the sounds the cubit announces through the [BattleAudio] that
/// [audioBuilder] makes for [world] (Observer, as the view is for the shots):
/// it listens from the moment it is built until it goes, and takes [child] as
/// it is. The player's settings decide what is heard: the sound effects and
/// the ambience music, each on or off, as they change. A new [world] gets a
/// new audio, since the sound follows the scene that is drawn.
/// {@endtemplate}
class SoundListener extends StatefulWidget {
  /// {@macro sound_listener}
  const new({
    required this.world,
    required this.audioBuilder,
    required this.child,
    super.key,
  });

  /// The world the sounds are heard in.
  final BattleWorld world;

  /// Makes the audio for [world].
  final BattleAudio Function(BattleWorld world) audioBuilder;

  /// What is shown.
  final Widget child;

  @override
  State<SoundListener> createState() => _SoundListenerState();
}

class _SoundListenerState extends State<SoundListener> {
  late BattleAudio _audio;
  late final SettingsCubit _settings;
  late final StreamSubscription<List<SoundCue>> _sounds;

  @override
  void initState() {
    super.initState();
    _audio = widget.audioBuilder(widget.world);
    _settings = context.read<SettingsCubit>();
    _audio.setAmbience(on: _settings.state.ambience);
    _sounds = context.read<BattleCubit>().sounds.listen((cues) {
      if (_settings.state.soundEffects) _audio.play(cues);
    });
  }

  @override
  void didUpdateWidget(SoundListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.world != oldWidget.world) {
      _audio.dispose();
      _audio = widget.audioBuilder(widget.world)
        ..setAmbience(on: _settings.state.ambience);
    }
  }

  @override
  void dispose() {
    unawaited(_sounds.cancel());
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<SettingsCubit, PlayerSettings>(
        listenWhen: (before, after) => before.ambience != after.ambience,
        listener: (context, settings) =>
            _audio.setAmbience(on: settings.ambience),
        child: widget.child,
      );
}
