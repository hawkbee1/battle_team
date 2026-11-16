import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';

/// {@template sound_cues}
/// Turns what the host tells a section of its tick into the sounds to play
/// (Adapter, as `ShotEffects` is for what the world draws): a shot for a seen
/// shooter, an injury or a death for a seen unit hit, a move for a seen unit
/// that sets off, and the end of the battle for the player's team.
///
/// The shots, the injuries and the deaths come from the shot effects of the
/// same message, which `ShotEffects` already cut down to what the section was
/// told (COMBAT-57, COMBAT-58, decisions 234 and 237): a sound has a place only
/// where the screen draws something. A shot whose shooter is not seen makes no
/// sound. A single volley that hits several units sounds once (a burst is one
/// sound).
///
/// The end of the battle: the player's team is eliminated (HQ-18): defeat, at
/// once, as `Eliminated` says it. The battle ends with the player's team the
/// winner: victory; with another winner: defeat, unless the team was
/// eliminated already and heard it then.
/// {@endtemplate}
class SoundCues {
  /// {@macro sound_cues}
  const new();

  /// The sounds of [message], which [view] holds already, with the [effects]
  /// that `ShotEffects` made of it, for a player of [team] (null before the
  /// sign-in: the end of the battle is then silent).
  List<SoundCue> of(
    HostMessage message,
    HeldView view,
    List<ShotEffect> effects, {
    required String? team,
  }) {
    if (message is! TickUpdate) return const [];
    return [
      ..._shots(effects),
      ..._moves(message, view),
      ..._end(message, team),
    ];
  }

  List<SoundCue> _shots(List<ShotEffect> effects) {
    // A volley that hits three units draws three tracers from one muzzle.
    final heard = <(Position, String)>{};
    final cues = <SoundCue>[];
    for (final effect in effects) {
      switch (effect) {
        case Tracer(:final from, :final weapon):
        case MuzzleFlash(at: final from, :final weapon):
          if (heard.add((from, weapon))) {
            cues.add(SoundCue(Sound.shot, at: from, subject: weapon));
          }
        case HitMark(:final at, :final result):
          cues.add(
            SoundCue(
              result == ImpactResult.killed ? Sound.death : Sound.injury,
              at: at,
            ),
          );
      }
    }
    return cues;
  }

  List<SoundCue> _moves(TickUpdate update, HeldView view) => [
    for (final event in update.events)
      if (event is MoveStarted)
        // An HQ or a relic that moves has no unit in the view.
        if (view.units[event.moverId] case UnitView(
          :final position?,
          :final unitType,
        ))
          SoundCue(Sound.move, at: position, subject: unitType),
  ];

  List<SoundCue> _end(TickUpdate update, String? team) {
    if (team == null) return const [];
    return [
      for (final event in update.events)
        switch (event) {
          Eliminated(team: final lost) when lost == team => const SoundCue(
            Sound.defeat,
          ),
          BattleEnded(:final winner) when winner == team => const SoundCue(
            Sound.victory,
          ),
          BattleEnded(:final eliminated) when !eliminated.contains(team) =>
            const SoundCue(Sound.defeat),
          _ => null,
        },
    ].nonNulls.toList();
  }
}
