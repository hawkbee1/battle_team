import 'dart:math' as math;

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/fog/model/fog_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_host.dart';
import '../helpers/fog.dart';
import '../helpers/real_cubit.dart';

const _cell = 10.0;

/// Whether the cell ([x], [y]) is within [metres] of [unit]: the centres of
/// the two cells.
bool _within(UnitView unit, int x, int y, double metres) {
  final from = unit.position!;
  final dx = (x + 0.5) * _cell - ((from.x / _cell).floor() + 0.5) * _cell;
  final dy = (y + 0.5) * _cell - ((from.y / _cell).floor() + 0.5) * _cell;
  return math.sqrt(dx * dx + dy * dy) <= metres;
}

/// Plays [host] through the real cubit, repository, client and codec, and
/// checks at every message of the host that the fog lights only the ground
/// within sight of the section's own units (decision 237): the oracle sees
/// the snapshot and the fog cubit that followed it. Gives what the stream
/// held, so that a test can show it was not an empty proof.
Future<({BattleCubit battle, FogCubit fog, Map<String, int> held})> _play(
  FakeHost host, {
  FogTracker? tracker,
}) async {
  final terrain = testTerrain();
  // A unit standing higher than the ground sees farther (MAP-33), up to a
  // cap: on the flat map only a flying unit does, by the flying limit above
  // it; on a map with relief, by up to the cap.
  final bonus = tracker == null
      ? math.min(
          terrain.vision.heightBonusMaxM,
          terrain.flyingMaxAboveHighestTerrainM *
              terrain.vision.heightBonusMPerM,
        )
      : terrain.vision.heightBonusMaxM;
  final battle = realCubit(host);
  final fog = realFogCubit(battle, tracker: tracker);
  final held = {'snapshots': 0, 'others': 0, 'lit': 0, 'outside': 0};
  final spy = battle.repository.snapshots.listen((snapshot) {
    final model = fog.state.model;
    final weather = snapshot.weather;
    if (weather == null) return;
    held['snapshots'] = held['snapshots']! + 1;
    final own = [
      for (final unit in snapshot.units.values)
        if (unit.private != null && unit.position != null) unit,
    ];
    held['others'] =
        held['others']! +
        snapshot.units.values.where((unit) => unit.private == null).length;
    // MAP-29: a unit drawn, its own or another's, stands on ground in sight.
    for (final unit in snapshot.units.values) {
      final at = unit.position;
      if (at == null) continue;
      if (model.levelAt(at.x, at.y) != FogLevel.lit) {
        held['outside'] = held['outside']! + 1;
      }
    }
    for (var y = 0; y < model.depth; y++) {
      for (var x = 0; x < model.width; x++) {
        if (!model.isLit(x, y)) continue;
        held['lit'] = held['lit']! + 1;
        expect(
          own.any(
            (unit) => _within(
              unit,
              x,
              y,
              unit.private!.sightRangeM * terrain.weather[weather]! +
                  (tracker != null || unit.flying ? bonus : 0),
            ),
          ),
          isTrue,
          reason: 'a cell lit away from every own unit',
        );
      }
    }
  });
  addTearDown(spy.cancel);
  addTearDown(fog.close);
  addTearDown(battle.close);
  battle.start();
  await pumpEventQueue(times: 500);
  return (battle: battle, fog: fog, held: held);
}

void main() {
  group('the fog over the host streams', () {
    test('MAP-29 nothing outside the lit area is drawn, and decision 237 '
        'the fog lights only around the own units of the section, on the '
        'valley, at every message of recorded streams', () async {
      var others = 0;
      var lit = 0;
      var outside = 0;
      for (final name in ['clear_s-1', 'clear_s-2', 'fog_s-1', 'fog_s-2']) {
        final played = await _play(
          FakeHost.recorded(name),
          tracker: testTracker(sight: valleySight()),
        );
        outside += played.held['outside']!;

        expect(played.held['snapshots'], greaterThan(5), reason: name);
        others += played.held['others']!;
        lit += played.held['lit']!;
        expect(played.fog.state.model.litCount, greaterThan(0), reason: name);
      }
      // The proof is not empty: units of other sections were in the views,
      // and ground was lit.
      expect(others, greaterThan(0));
      expect(lit, greaterThan(0));
      // MAP-29: no unit is drawn on ground out of the section's sight.
      expect(outside, 0);
    });

    test('M7.9 the fog follows a late join like one from the start: the '
        'ground in sight at the end is the same', () async {
      final early = await _play(FakeHost.recorded('clear_s-1'));
      final late = await _play(FakeHost.recorded('clear_s-1_late'));

      final lit = {
        for (var y = 0; y < 30; y++)
          for (var x = 0; x < 30; x++)
            if (early.fog.state.model.isLit(x, y)) (x, y),
      };
      expect(lit, isNotEmpty);
      expect({
        for (var y = 0; y < 30; y++)
          for (var x = 0; x < 30; x++)
            if (late.fog.state.model.isLit(x, y)) (x, y),
      }, lit);
    });

    test('decision 237 an unseen hit, a shot of a unit seen at a target not '
        'seen, and an enemy that leaves sight light nothing and leave no '
        'mark', () async {
      const own = blueCommander;
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: blueView.section,
          units: const [own, redSoldier],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
        updates: [
          TickUpdate(
            at: blueView.at + const Duration(seconds: 1),
            unseenHits: const [
              UnseenHit(
                targetId: 'c-1',
                damage: 12,
                result: ImpactResult.damaged,
              ),
            ],
          ),
          TickUpdate(
            at: blueView.at + const Duration(seconds: 2),
            fired: const [
              Fired(
                attackerId: 'r-1',
                sectionId: 's-red',
                weapon: 'rifle',
                shots: 1,
              ),
            ],
          ),
          TickUpdate(
            at: blueView.at + const Duration(seconds: 3),
            gone: const ['r-1'],
          ),
        ],
      );
      final battle = realCubit(host);
      final fog = realFogCubit(
        battle,
        tracker: testTracker(
          sight: testSight(map: flatMap(width: 100, depth: 100)),
        ),
      );
      final states = <FogState>[];
      final subscription = fog.stream.listen(states.add);
      addTearDown(subscription.cancel);
      addTearDown(fog.close);
      addTearDown(battle.close);

      battle.start();
      await pumpEventQueue(times: 500);

      // One state: the view lit the ground around the commander. The hit,
      // the shot and the enemy that left sight changed nothing.
      expect(states, hasLength(1));
      expect(battle.state.units.containsKey('r-1'), isFalse);
      final model = fog.state.model;
      final enemy = redSoldier.position!;
      expect(
        model.levelAt(enemy.x, enemy.y),
        FogLevel.never,
        reason: 'the enemy stood where no own unit sees',
      );
      expect(model.litCount, greaterThan(0));
    });
  });
}
