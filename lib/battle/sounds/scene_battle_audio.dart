// coverage:ignore-file
// Plays through SoLoud, which needs a sound device and its native library,
// which `flutter test` does not have.

import 'dart:async';
import 'dart:math' as math;

import 'package:battle_team/battle/sounds/battle_audio.dart';
import 'package:battle_team/battle/sounds/sound_bank.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:flutter_scene/audio.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_soloud/flutter_scene_soloud.dart';
import 'package:logging/logging.dart';

/// {@template scene_battle_audio}
/// The battle's sounds through flutter_scene's audio, on SoLoud: the engine
/// is a component of the scene's root, the ears follow the scene's camera (no
/// `AudioListener`), and a sound with a place plays there in 3D, fading with
/// the distance from the camera. Without a place (the end of the battle) it
/// plays flat.
///
/// Each file loads once, when this is built. A sound that comes before its
/// file loaded, or when [maxVoices] already play, is dropped (the end of the
/// battle is never dropped for the voices), and `SoundGate` thins out a kind
/// that comes too often. If the sound cannot start (no device), it logs on
/// `battle_team.SceneBattleAudio` and plays nothing: the battle goes on.
/// {@endtemplate}
class SceneBattleAudio implements BattleAudio {
  /// {@macro scene_battle_audio}
  new(this._scene, {this.maxVoices = 24, math.Random? random})
    : _random = random ?? math.Random() {
    _scene.root.addComponent(_engine);
    unawaited(Future.wait(SoundBank.files.map(_load)));
  }

  /// The most sounds that play at once.
  final int maxVoices;

  final Scene _scene;
  final math.Random _random;
  final _engine = SoloudAudioEngine();
  final _gate = SoundGate();
  final _clock = Stopwatch()..start();
  final _clips = <String, AudioClip>{};
  final _voices = <AudioVoice>[];
  var _disposed = false;
  var _ambience = false;
  AudioVoice? _ambienceVoice;

  static final _log = Logger('battle_team.SceneBattleAudio');

  /// A sound heard from 250 metres or nearer is at
  /// full volume, then fades with the distance, as the top-down camera is
  /// high and its view wide.
  static final _attenuation = AudioAttenuation(
    minDistance: 250,
    maxDistance: 3000,
  );

  Future<void> _load(String file) async {
    try {
      final clip = await _engine.loadClip('${SoundBank.folder}$file.wav');
      if (_disposed) {
        clip.dispose();
      } else {
        _clips[file] = clip;
        if (file == SoundBank.ambienceFile) _syncAmbience();
      }
    } on Object catch (error) {
      _log.warning('sound $file not loaded: ${error.runtimeType}');
    }
  }

  @override
  void play(Iterable<SoundCue> cues) {
    if (_disposed) return;
    _voices.removeWhere((voice) => !voice.isPlaying);
    for (final cue in cues) {
      final ending = cue.sound == Sound.victory || cue.sound == Sound.defeat;
      final clip = _clips[SoundBank.fileOf(cue)];
      if (clip == null || !_gate.allow(cue.sound, _clock.elapsed)) continue;
      if (!ending && _voices.length >= maxVoices) continue;
      final spread = SoundBank.pitchSpreadOf(cue);
      try {
        _voices.add(
          _engine.playOneShot(
            clip,
            position: switch (cue.at) {
              final at? => worldOf(at),
              null => null,
            },
            volume: SoundBank.volumeOf(cue),
            pitch: 1 + (_random.nextDouble() * 2 - 1) * spread,
            attenuation: _attenuation,
          ),
        );
      } on Object catch (error) {
        // The engine is not up yet, or the device is gone.
        _log.warning(
          'sound ${cue.sound.name} not played: ${error.runtimeType}',
        );
      }
    }
  }

  @override
  void setAmbience({required bool on}) {
    _ambience = on;
    _syncAmbience();
  }

  /// Starts the ambience loop when it is wanted and loaded, stops it when it
  /// is not wanted.
  void _syncAmbience() {
    if (_disposed) return;
    final playing = _ambienceVoice?.isPlaying ?? false;
    if (!_ambience) {
      _ambienceVoice?.stop();
      _ambienceVoice = null;
    } else if (!playing) {
      final clip = _clips[SoundBank.ambienceFile];
      if (clip == null) return;
      try {
        _ambienceVoice = _engine.createVoice(clip)
          ..volume = SoundBank.ambienceVolume
          ..looping = true
          ..setPositional(false)
          ..start();
      } on Object catch (error) {
        _log.warning('ambience not played: ${error.runtimeType}');
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final voice in _voices) {
      voice.stop();
    }
    _voices.clear();
    _ambienceVoice?.stop();
    _ambienceVoice = null;
    _scene.root.removeComponent(_engine);
    for (final clip in _clips.values) {
      clip.dispose();
    }
    _clips.clear();
  }
}
