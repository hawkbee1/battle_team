import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/fog/model/fog_model.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/fake_world.dart';
import '../../helpers/fog.dart';
import '../../helpers/real_cubit.dart';

/// The blue section's view with two relics, one of them red, and a victory
/// countdown of red's.
final _view = SectionView(
  weather: 'clear',
  at: blueView.at,
  section: blueView.section,
  units: const [blueCommander, redSoldier],
  hqs: blueView.hqs,
  relics: const [
    RelicView(
      relicId: 'relic-1',
      position: Position(20500, 30500, 3000),
      owner: 'red',
    ),
    RelicView(relicId: 'relic-2', position: Position(30500, 30500, 3000)),
  ],
  hold: const HoldView(
    team: 'red',
    since: Duration(minutes: 30),
    winsAt: Duration(hours: 25),
  ),
  world: blueView.world,
);

void main() {
  late MapData map;
  late UnitBodies bodies;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    map = await loadMapAsset(rootBundle, 'saint_lo_1km');
    bodies = await loadUnitBodies(rootBundle);
  });

  group('$BattleView with the fog and the alerts', () {
    late FakeWorld world;

    /// Plays [host] through the real cubits and shows it.
    Future<void> play(
      WidgetTester tester,
      FakeHost host, {
      Locale? locale,
    }) async {
      final battle = realCubit(host);
      final storage = realStorageCubit(battle);
      final fog = realFogCubit(
        battle,
        tracker: testTracker(
          sight: testSight(map: flatMap(width: 100, depth: 100)),
        ),
      );
      final alerts = realAlertsCubit(battle);
      addTearDown(storage.close);
      addTearDown(fog.close);
      addTearDown(alerts.close);
      addTearDown(battle.close);
      world = FakeWorld(map);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<StorageCubit>.value(value: storage),
              BlocProvider<FogCubit>.value(value: fog),
              BlocProvider<AlertsCubit>.value(value: alerts),
              BlocProvider<BattleCubit>.value(value: battle),
            ],
            child: BattleView(
              map: map,
              bodies: bodies,
              world: world,
              sceneBuilder: (_, _, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        battle.start();
        await pumpEventQueue(times: 500);
      });
      await tester.pump();
    }

    testWidgets('MAP-27 MAP-33 the world is told the ground in the dark '
        'first, then what the units of the section see', (tester) async {
      await play(tester, FakeHost(view: _view));

      expect(world.fogs.first.litCount, 0);
      expect(world.fog!.litCount, greaterThan(0));
      // The commander at (505 m, 55 m) sees around it; the soldier 145 m
      // away, beyond its sight, is not lit.
      expect(world.fog!.levelAt(505, 55), FogLevel.lit);
      expect(world.fog!.levelAt(505, 200), FogLevel.never);
    });

    testWidgets(
      'MAP-49 the strip shows the owners of the relics and the countdown '
      'of every team, whatever the fog',
      (tester) async {
        await play(tester, FakeHost(view: _view));

        expect(find.text('Relics:'), findsOneWidget);
        expect(find.text('red 1'), findsOneWidget);
        expect(find.text('free 1'), findsOneWidget);
        expect(find.text('red wins in 24.0 h'), findsOneWidget);
      },
    );

    testWidgets('MAP-49 the strip reads in French', (tester) async {
      await play(tester, FakeHost(view: _view), locale: const Locale('fr'));

      expect(find.text('Reliques:'), findsOneWidget);
      expect(find.text('libres 1'), findsOneWidget);
      expect(find.text('red gagne dans 24.0 h'), findsOneWidget);
    });

    testWidgets('RELIC-10 decision 233 the relic alert the host sends on '
        'connecting shows once as a banner, and the player dismisses it', (
      tester,
    ) async {
      const alert = RelicAlert(
        at: Duration(hours: 2),
        relicId: 'relic-9',
        team: 'red',
      );
      await play(tester, FakeHost(view: _view, updates: [alert, alert]));

      expect(find.text('red took the relic relic-9'), findsOneWidget);

      // The countdown the view came with has a banner too: dismiss the one of
      // the relic.
      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('red took the relic relic-9'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.text('Dismiss'),
        ),
      );
      await tester.pump();

      expect(find.text('red took the relic relic-9'), findsNothing);
    });

    testWidgets('RELIC-16 the countdown banner shows for the section when it '
        'connects to a running countdown', (tester) async {
      await play(tester, FakeHost(view: _view));

      expect(
        find.text(
          'red holds the relics: it wins in 24.0 h unless one is taken back',
        ),
        findsOneWidget,
      );
    });
  });
}
