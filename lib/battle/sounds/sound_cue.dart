import 'package:battle_protocol/battle_protocol.dart';
import 'package:equatable/equatable.dart';

/// What the battle makes a sound for.
enum Sound {
  /// A unit the section sees starts moving.
  move,

  /// A seen unit fires.
  shot,

  /// A seen unit is hurt and still there.
  injury,

  /// A seen unit dies, or an HQ or an object is destroyed.
  death,

  /// The player's team wins the battle.
  victory,

  /// The player's team is eliminated, or loses the battle.
  defeat,
}

/// {@template sound_cue}
/// A sound the battle asks for, once: transient like a `ShotEffect`, never
/// part of the state, so that a rebuild does not play it again. It holds only
/// what the section may hear: a sound has a place only where the section sees
/// its source (COMBAT-57, COMBAT-58, decision 237).
/// {@endtemplate}
class SoundCue extends Equatable {
  /// {@macro sound_cue}
  const new(this.sound, {this.at, this.subject});

  /// What it is for.
  final Sound sound;

  /// Where it comes from; null for a sound with no place, which plays flat
  /// (the end of the battle).
  final Position? at;

  /// What makes it, when that changes the sound: the unit type that moves, the
  /// weapon that fires.
  final String? subject;

  @override
  List<Object?> get props => [sound, at, subject];
}
