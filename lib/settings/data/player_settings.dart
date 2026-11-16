import 'package:battle_team/settings/data/key_bindings.dart';
import 'package:equatable/equatable.dart';

/// {@template player_settings}
/// What the player chose for this device: whether the battle's sound effects
/// play, whether its ambience music plays, and the keys of the battle view.
/// Both sounds are on until the player turns them off.
/// {@endtemplate}
class PlayerSettings extends Equatable {
  /// {@macro player_settings}
  const new({
    this.soundEffects = true,
    this.ambience = true,
    this.keys = KeyBindings.defaults,
  });

  /// Whether the shots, the moves, the hits, the deaths and the end of the
  /// battle are heard.
  final bool soundEffects;

  /// Whether the ambience music plays during the battle.
  final bool ambience;

  /// The keys of the battle view.
  final KeyBindings keys;

  /// These settings with the values given.
  PlayerSettings copyWith({
    bool? soundEffects,
    bool? ambience,
    KeyBindings? keys,
  }) => PlayerSettings(
    soundEffects: soundEffects ?? this.soundEffects,
    ambience: ambience ?? this.ambience,
    keys: keys ?? this.keys,
  );

  @override
  List<Object?> get props => [soundEffects, ambience, keys];
}
