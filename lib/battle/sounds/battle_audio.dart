import 'package:battle_team/battle/sounds/sound_cue.dart';

/// {@template battle_audio}
/// What the view needs of the sound: it plays the sounds the section hears. A
/// Strategy for swappable players (Gang of Four), as `BattleWorld` is for the
/// renderers: `SceneBattleAudio` plays them through flutter_scene's audio,
/// tests use a fake, having no sound device.
/// {@endtemplate}
abstract interface class BattleAudio {
  /// Plays [cues], each once, where it comes from. A sound that cannot play
  /// (not loaded yet, too many at once) is dropped: sound never holds the
  /// battle back.
  void play(Iterable<SoundCue> cues);

  /// Whether the ambience music plays: a loop, from the moment it is on and
  /// loaded until it is off. Off at first.
  void setAmbience({required bool on});

  /// Stops what plays and lets go of the sounds.
  void dispose();
}

/// {@template silent_battle_audio}
/// A [BattleAudio] that plays nothing: for a world that is not a scene, and
/// for a device with no sound.
/// {@endtemplate}
class SilentBattleAudio implements BattleAudio {
  /// {@macro silent_battle_audio}
  const new();

  @override
  void play(Iterable<SoundCue> cues) {}

  @override
  void setAmbience({required bool on}) {}

  @override
  void dispose() {}
}
