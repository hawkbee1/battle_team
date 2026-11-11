import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/alerts/widgets/alert_banners.dart';
import 'package:battle_team/alerts/widgets/status_strip.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fog.dart';
import '../../helpers/mocks.dart';
import '../../helpers/pump_app.dart';

const _relics = [
  RelicView(relicId: 'relic-1', position: Position(0, 0, 0), owner: 'red'),
  RelicView(relicId: 'relic-2', position: Position(0, 0, 0), owner: 'blue'),
  RelicView(relicId: 'relic-3', position: Position(0, 0, 0), owner: 'red'),
  RelicView(relicId: 'relic-4', position: Position(0, 0, 0)),
];

const _hold = HoldView(
  team: 'red',
  since: Duration(minutes: 30),
  winsAt: Duration(hours: 25),
);

BattleSnapshot _snapshot({HoldView? hold}) => BattleSnapshot(
  units: const {},
  hqs: const [],
  relics: _relics,
  hold: hold,
  section: const SectionPrivate(money: 0, xp: 0),
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group('the alerts on the battle screen', () {
    late StreamController<BattleSnapshot> snapshots;
    late StreamController<RelicAlert> alerts;
    late AlertsCubit cubit;

    setUp(() {
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      alerts = StreamController<RelicAlert>.broadcast(sync: true);
      cubit = alertsCubit(snapshots.stream, alerts: alerts.stream);
      addTearDown(() async {
        await cubit.close();
        await snapshots.close();
        await alerts.close();
      });
    });

    /// The cubit lives in the real zone: lets its streams deliver, then
    /// builds the frame.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    }

    Future<void> pump(WidgetTester tester, {Locale? locale}) => tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: Column(
          children: [
            StatusStrip(builder: (child) => child),
            AlertBanners(builder: (child) => child),
          ],
        ),
      ),
      locale: locale,
    );

    testWidgets('MAP-49 the strip shows nothing until the view of the host '
        'came', (tester) async {
      await pump(tester);

      expect(find.textContaining('Relics'), findsNothing);
    });

    testWidgets(
      'MAP-49 the strip shows the owners of the relics whatever the fog, '
      'in English',
      (tester) async {
        await pump(tester);

        snapshots.add(_snapshot());
        await settle(tester);

        expect(find.text('Relics:'), findsOneWidget);
        expect(find.text('red 2'), findsOneWidget);
        expect(find.text('blue 1'), findsOneWidget);
        expect(find.text('free 1'), findsOneWidget);
      },
    );

    testWidgets('MAP-49 the strip shows the owners of the relics, in French', (
      tester,
    ) async {
      await pump(tester, locale: const Locale('fr'));

      snapshots.add(_snapshot());
      await settle(tester);

      expect(find.text('Reliques:'), findsOneWidget);
      expect(find.text('libres 1'), findsOneWidget);
    });

    testWidgets('RELIC-16 the strip counts the victory countdown down '
        'between the messages of the host, by the battle time of the client', (
      tester,
    ) async {
      await pump(tester);
      snapshots.add(_snapshot(hold: _hold));
      await settle(tester);
      expect(find.text('red wins in 24.0 h'), findsOneWidget);

      when(() => (cubit.repository as MockBattleRepository).battleTime)
          .thenReturn(const Duration(hours: 24, minutes: 30));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('red wins in 30 min'), findsOneWidget);
    });

    testWidgets('RELIC-16 the countdown reads in French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      snapshots.add(_snapshot(hold: _hold));
      await settle(tester);

      expect(find.text('red gagne dans 24.0 h'), findsOneWidget);
    });

    testWidgets('RELIC-10 the banner says who took the relic, and the '
        'player dismisses it', (tester) async {
      await pump(tester);

      alerts.add(
        const RelicAlert(
          at: Duration(hours: 2),
          relicId: 'relic-1',
          team: 'red',
        ),
      );
      await settle(tester);

      expect(find.text('red took the relic relic-1'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await settle(tester);

      expect(find.text('red took the relic relic-1'), findsNothing);
    });

    testWidgets('RELIC-10 the banner reads in French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      alerts.add(
        const RelicAlert(
          at: Duration(hours: 2),
          relicId: 'relic-1',
          team: 'red',
        ),
      );
      await settle(tester);

      expect(find.text('red a pris la relique relic-1'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
    });

    testWidgets('RELIC-16 the banners say when a countdown started and when '
        'it was reset, in both languages', (tester) async {
      await pump(tester);
      snapshots.add(_snapshot(hold: _hold));
      await settle(tester);
      expect(
        find.text(
          'red holds the relics: it wins in 24.0 h unless one is taken back',
        ),
        findsOneWidget,
      );

      snapshots.add(_snapshot());
      await settle(tester);
      expect(find.text('The victory countdown was reset'), findsOneWidget);
      expect(find.text('Dismiss'), findsNWidgets(2));
    });

    testWidgets('RELIC-16 the banners read in French', (tester) async {
      await pump(tester, locale: const Locale('fr'));
      snapshots
        ..add(_snapshot(hold: _hold))
        ..add(_snapshot());
      await settle(tester);

      expect(
        find.textContaining('red tient les reliques : victoire dans 24.0 h'),
        findsOneWidget,
      );
      expect(
        find.text('Le compte à rebours de la victoire est réinitialisé'),
        findsOneWidget,
      );
    });
  });
}
