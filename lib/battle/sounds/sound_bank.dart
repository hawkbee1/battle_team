import 'package:battle_team/battle/sounds/sound_cue.dart';

/// {@template sound_bank}
/// Which file a [SoundCue] plays, and how loud: display data, not game rules.
/// The files are `assets/sounds/*.wav`, written by
/// `tool/sounds/generate_sounds.dart`; a recorded file with the same name
/// replaces one.
/// {@endtemplate}
abstract final class SoundBank {
  /// Where the files are, in the assets.
  static const folder = 'assets/sounds/';

  /// Every file of the bank, to load.
  static const List<String> files = [
    'rifle',
    'machine_gun',
    'cannon',
    'blast',
    'foot',
    'vehicle',
    'hit',
    'death',
    'victory',
    'defeat',
    ambienceFile,
  ];

  /// The ambience music: a loop, played flat, under the effects.
  static const ambienceFile = 'ambience';

  /// How loud the ambience plays, from 0 to 1: low, under the effects.
  static const ambienceVolume = 0.3;

  /// The unit types that move on foot (`plan/data/units.yaml`); every other
  /// moves with an engine.
  static const onFoot = {
    'commander',
    'soldier',
    'engineer',
    'scout',
    'medic',
    'radio',
  };

  /// The file name of [cue], without its folder and extension.
  static String fileOf(SoundCue cue) => switch (cue.sound) {
    Sound.move => onFoot.contains(cue.subject) ? 'foot' : 'vehicle',
    Sound.shot => switch (cue.subject) {
      'machine_gun' => 'machine_gun',
      'anti_tank' || 'anti_air' || 'artillery' => 'cannon',
      'explosive' => 'blast',
      _ => 'rifle',
    },
    Sound.injury => 'hit',
    Sound.death => 'death',
    Sound.victory => 'victory',
    Sound.defeat => 'defeat',
  };

  /// The asset key of [cue].
  static String assetOf(SoundCue cue) => '$folder${fileOf(cue)}.wav';

  /// How loud [cue] plays against the others, from 0 to 1.
  static double volumeOf(SoundCue cue) => switch (fileOf(cue)) {
    'machine_gun' => 0.5,
    'foot' => 0.5,
    'vehicle' => 0.6,
    'rifle' || 'hit' => 0.7,
    'death' => 0.9,
    _ => 1,
  };

  /// How the pitch of [cue] may vary around 1, either way, so that the same
  /// sound twice does not sound like a machine: none for the end of the
  /// battle.
  static double pitchSpreadOf(SoundCue cue) => switch (cue.sound) {
    Sound.victory || Sound.defeat => 0,
    _ => 0.06,
  };
}

/// {@template sound_gate}
/// Lets a sound through at most once in its kind's gap: a battle of a
/// hundred players fires hundreds of shots a second, and a mixer given all of
/// them plays mud. The end of the battle always goes through. It is given the
/// time, so that tests need no clock.
/// {@endtemplate}
class SoundGate {
  /// {@macro sound_gate}
  new({this.gaps = defaultGaps});

  /// The shortest time between two sounds of a kind.
  static const Map<Sound, Duration> defaultGaps = {
    Sound.move: Duration(milliseconds: 150),
    Sound.shot: Duration(milliseconds: 40),
    Sound.injury: Duration(milliseconds: 60),
    Sound.death: Duration(milliseconds: 120),
  };

  /// The shortest time between two sounds of each kind; a kind with none is
  /// never held back.
  final Map<Sound, Duration> gaps;

  final _last = <Sound, Duration>{};

  /// Whether a sound of kind [sound] may play at [now]; it is counted as
  /// played when it may.
  bool allow(Sound sound, Duration now) {
    final gap = gaps[sound];
    final last = _last[sound];
    if (gap != null && last != null && now - last < gap) return false;
    _last[sound] = now;
    return true;
  }
}
