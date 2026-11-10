import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';

/// {@template shot_effects}
/// Turns what the host tells a section of its tick into the effects the
/// world draws (Adapter from the stream's messages to drawing): a tracer and a
/// hit mark for a seen shot that hit a seen unit, a muzzle flash for a seen
/// unit that fired with its outcome unknown, a hit mark alone for a hit by an
/// unseen shooter.
///
/// It reads only the fields the host cut down to what the section sees
/// (COMBAT-57, COMBAT-58): `events` (a single seen shot is an [Attacked]),
/// `bursts`, `fired` and `unseenHits`. It adds nothing: an effect has no
/// position, so no origin and no direction, for what the section was not
/// told (decisions 234 and 237).
///
/// A unit killed by a shot has left the view by the time its message is
/// applied, so the effects look for a position in the view and then in the
/// view as it was at the previous message.
/// {@endtemplate}
class ShotEffects {
  /// {@macro shot_effects}
  new();

  /// The positions the view held at the last message, units and HQs by ID.
  final _before = <String, Position>{};

  /// The effects of [message], which [view] holds already. Remembers the
  /// positions of [view] for the next message.
  List<ShotEffect> of(HostMessage message, HeldView view) {
    final effects = message is TickUpdate
        ? _effectsOf(message, view)
        : const <ShotEffect>[];
    _before
      ..clear()
      ..addEntries([
        for (final unit in view.units.values)
          if (unit.position case final position?)
            MapEntry(unit.unitId, position),
        for (final hq in view.hqs.values) MapEntry(_hqId(hq.team), hq.position),
      ]);
    return effects;
  }

  List<ShotEffect> _effectsOf(TickUpdate update, HeldView view) {
    Position? where(String id) {
      final unit = view.units[id]?.position;
      if (unit != null) return unit;
      final hq = id.startsWith(_hqPrefix)
          ? view.hqs[id.substring(_hqPrefix.length)]?.position
          : null;
      return hq ?? _before[id];
    }

    // A seen shooter whose shot hit units the section sees: a tracer and a
    // hit mark for each.
    List<ShotEffect> seen(String attackerId, String weapon, List<Impact> hits) {
      final from = where(attackerId);
      if (from == null) return const [];
      final effects = <ShotEffect>[];
      for (final Impact(:targetId, :result) in hits) {
        if (where(targetId) case final to?) {
          effects
            ..add(Tracer(from: from, to: to, weapon: weapon))
            ..add(HitMark(at: to, result: result));
        }
      }
      return effects.isEmpty
          ? [MuzzleFlash(at: from, weapon: weapon)]
          : effects;
    }

    return [
      for (final event in update.events)
        if (event is Attacked)
          ...seen(event.attackerId, event.weapon, event.impacts),
      for (final burst in update.bursts)
        ...seen(burst.attackerId, burst.weapon, burst.impacts),
      // A shot whose outcome the section does not see whole: the shooter
      // fired, and only the hits on units it sees are given. No tracer.
      for (final fired in update.fired) ...[
        if (where(fired.attackerId) case final from?)
          MuzzleFlash(at: from, weapon: fired.weapon),
        for (final Impact(:targetId, :result) in fired.impacts)
          if (where(targetId) case final at?) HitMark(at: at, result: result),
      ],
      // A hit by a shooter the section does not see: the unit hit, nothing of
      // the shooter.
      for (final UnseenHit(:targetId, :result) in update.unseenHits)
        if (where(targetId) case final at?) HitMark(at: at, result: result),
    ];
  }

  static const _hqPrefix = 'hq-';

  static String _hqId(String team) => '$_hqPrefix$team';
}
