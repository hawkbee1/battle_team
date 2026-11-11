import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fog.dart';
import '../../helpers/log_capture.dart';

BattleSnapshot _snapshot({
  List<RelicView> relics = const [],
  HoldView? hold,
  bool whole = true,
}) => BattleSnapshot(
  units: const {},
  hqs: const [],
  relics: relics,
  hold: hold,
  section: whole ? const SectionPrivate(money: 0, xp: 0) : null,
);

const _alert = RelicAlert(
  at: Duration(hours: 2),
  relicId: 'relic-1',
  team: 'red',
);

const _relics = [
  RelicView(relicId: 'relic-1', position: Position(0, 0, 0), owner: 'red'),
  RelicView(relicId: 'relic-2', position: Position(0, 0, 0), owner: 'blue'),
  RelicView(relicId: 'relic-3', position: Position(0, 0, 0), owner: 'red'),
  RelicView(relicId: 'relic-4', position: Position(0, 0, 0)),
];

void main() {
  group(AlertsCubit, () {
    late StreamController<BattleSnapshot> snapshots;
    late StreamController<RelicAlert> alerts;
    late AlertsCubit cubit;
    late LogCapture logs;

    setUp(() {
      logs = LogCapture();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      alerts = StreamController<RelicAlert>.broadcast(sync: true);
      cubit = alertsCubit(snapshots.stream, alerts: alerts.stream);
    });

    tearDown(() async {
      await logs.cancel();
      await cubit.close();
      await snapshots.close();
      await alerts.close();
    });

    test('M7.9 banners and states compare by what they hold', () {
      expect(const CountdownReset(3), equals(const CountdownReset(3)));
      expect(const CountdownReset(3), isNot(equals(const CountdownReset(4))));
      expect(const AlertsState(), equals(const AlertsState()));
      expect(
        const AlertsState(),
        isNot(equals(const AlertsState(revision: 1))),
      );
    });

    test('M7.9 a state changed in one part keeps the others', () {
      const state = AlertsState(
        relics: [(relicId: 'relic-1', owner: 'red')],
        banners: [CountdownReset(7)],
      );

      final next = state.copyWith(hold: () => null);

      expect(next.relics, state.relics);
      expect(next.banners, state.banners);
      expect(next.revision, state.revision + 1);
    });

    test('M7.9 starts with nothing to show', () {
      expect(cubit.state.banners, isEmpty);
      expect(cubit.state.relics, isEmpty);
      expect(cubit.state.hold, isNull);
      expect(cubit.battleTime, const Duration(hours: 1));
    });

    test('RELIC-10 the relic alert shows as a banner that names the relic and '
        'its new owner', () {
      alerts.add(_alert);

      expect(cubit.state.banners, [
        const RelicTaken(
          0,
          relicId: 'relic-1',
          team: 'red',
          at: Duration(hours: 2),
        ),
      ]);
    });

    test('RELIC-10 decision 233 the relic alert shows once, also when it is '
        'received on connect and again after a crash', () {
      alerts
        ..add(_alert)
        ..add(_alert)
        ..add(
          const RelicAlert(
            at: Duration(hours: 3),
            relicId: 'relic-1',
            team: 'blue',
          ),
        );

      expect(cubit.state.banners.map((banner) => banner.id), [0, 1]);
      expect(logs.lines, contains('FINE a relic alert came again; shown once'));
    });

    test('M7.9 a banner stays until the player dismisses it', () {
      alerts
        ..add(_alert)
        ..add(
          const RelicAlert(
            at: Duration(hours: 3),
            relicId: 'relic-2',
            team: 'red',
          ),
        );

      snapshots.add(_snapshot(relics: _relics));
      expect(cubit.state.banners, hasLength(2));

      cubit.dismiss(0);
      expect(cubit.state.banners.map((banner) => banner.id), [1]);

      cubit.dismiss(1);
      expect(cubit.state.banners, isEmpty);
    });

    test('MAP-49 the relics and their owners come from the view, whatever '
        'the fog', () {
      snapshots.add(_snapshot(relics: _relics));

      expect(cubit.state.relics, [
        (relicId: 'relic-1', owner: 'red'),
        (relicId: 'relic-2', owner: 'blue'),
        (relicId: 'relic-3', owner: 'red'),
        (relicId: 'relic-4', owner: null),
      ]);
      expect(cubit.state.owned('red'), 2);
      expect(cubit.state.owned('blue'), 1);
      expect(cubit.state.owned(null), 1);
      expect(cubit.state.owners, ['red', 'blue']);
    });

    test('MAP-49 nothing is shown before the whole view', () {
      snapshots.add(_snapshot(relics: _relics, whole: false));

      expect(cubit.state.relics, isEmpty);
      expect(cubit.state.revision, 0);
    });

    test(
      'M7.9 says nothing again while the relics and the countdown stay',
      () async {
        final states = <AlertsState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);

        snapshots
          ..add(_snapshot(relics: _relics))
          ..add(_snapshot(relics: _relics))
          ..add(
            _snapshot(
              relics: [
                ..._relics.take(3),
                const RelicView(
                  relicId: 'relic-4',
                  position: Position(0, 0, 0),
                  owner: 'blue',
                ),
              ],
            ),
          );

        await pumpEventQueue();

        expect(states, hasLength(2));
        expect(cubit.state.owned('blue'), 2);
      },
    );

    test('RELIC-16 the countdown shows for every section, as a banner when '
        'it starts and in the strip while it runs', () {
      const hold = HoldView(
        team: 'red',
        since: Duration(minutes: 30),
        winsAt: Duration(hours: 25),
      );

      snapshots.add(_snapshot(relics: _relics, hold: hold));

      expect(cubit.state.hold, hold);
      expect(cubit.state.banners, [
        const CountdownStarted(0, team: 'red', remaining: Duration(hours: 24)),
      ]);
      expect(logs.lines, contains('INFO countdown running'));
    });

    test('RELIC-16 a countdown reset, and a countdown another team takes '
        'over, are alerts too', () {
      const red = HoldView(
        team: 'red',
        since: Duration.zero,
        winsAt: Duration(hours: 25),
      );
      const blue = HoldView(
        team: 'blue',
        since: Duration(hours: 2),
        winsAt: Duration(hours: 26),
      );

      snapshots
        ..add(_snapshot(hold: red))
        ..add(_snapshot(hold: blue))
        ..add(_snapshot());

      expect(cubit.state.hold, isNull);
      expect(cubit.state.banners.map((banner) => banner.runtimeType), [
        CountdownStarted,
        CountdownStarted,
        CountdownReset,
      ]);
      expect(logs.lines, contains('INFO countdown reset'));
    });

    test('a countdown already past is announced with no time left', () {
      snapshots.add(
        _snapshot(
          hold: const HoldView(
            team: 'red',
            since: Duration.zero,
            winsAt: Duration(minutes: 30),
          ),
        ),
      );

      expect(
        (cubit.state.banners.single as CountdownStarted).remaining,
        Duration.zero,
      );
    });

    test('decision 237 logs that an alert came, never which relic or team', () {
      alerts.add(_alert);

      final text = logs.texts.join('\n');
      expect(text, contains('relic alert'));
      expect(text, isNot(contains('relic-1')));
      expect(text, isNot(contains('red')));
    });
  });
}
