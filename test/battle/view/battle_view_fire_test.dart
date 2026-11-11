import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/alerts/cubit/alerts_cubit.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/shots/shot_effect.dart';
import 'package:battle_team/battle/widgets/weapon_panel.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/battle_space.dart';
import 'package:battle_team/fog/cubit/fog_cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../helpers/fake_host.dart';
import '../../helpers/fake_world.dart';
import '../../helpers/real_cubit.dart';

/// An enemy 20 m west of the rifleman: in range, and on screen from above,
/// clear of the panels.
const _near = UnitView(
  unitId: 'r-near',
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position(48500, 6000, 3000),
);

final _view = SectionView(
  weather: 'clear',
  at: armedView.at,
  section: armedView.section,
  units: const [blueCommander, blueRifleman, blueGun, _near],
  hqs: armedView.hqs,
  relics: armedView.relics,
  world: armedView.world,
);

void main() {
  late MapData map;
  late UnitBodies bodies;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    map = await loadMapAsset(rootBundle, 'saint_lo_1km');
    bodies = await loadUnitBodies(rootBundle);
  });

  group('$BattleView firing, over the real cubit and a fake host', () {
    late FakeHost host;
    late BattleCubit cubit;
    late FakeWorld world;
    late BattleCamera camera;

    /// Plays [_view] and shows it.
    Future<void> play(WidgetTester tester) async {
      host = FakeHost(view: _view);
      cubit = realCubit(host);
      final storage = realStorageCubit(cubit);
      addTearDown(storage.close);
      final fog = realFogCubit(cubit);
      addTearDown(fog.close);
      final alerts = realAlertsCubit(cubit);
      addTearDown(alerts.close);
      addTearDown(cubit.close);
      await tester.runAsync(() async {
        await cubit.start();
        await pumpEventQueue(times: 500);
      });
      world = FakeWorld(map);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<StorageCubit>.value(value: storage),
              BlocProvider<FogCubit>.value(value: fog),
              BlocProvider<AlertsCubit>.value(value: alerts),
              BlocProvider<BattleCubit>.value(value: cubit),
            ],
            child: BattleView(
              map: map,
              bodies: bodies,
              world: world,
              sceneBuilder: (_, _, scene, _) {
                camera = scene;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Lets the cubit's orders reach the host and its answers come back.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => pumpEventQueue(times: 500));
      await tester.pump();
    }

    /// The host sends [message] to the section.
    Future<void> hostSends(WidgetTester tester, HostMessage message) async {
      host.sockets.single.deliver(message);
      await settle(tester);
    }

    /// Where the unit [id] shows on the screen now.
    Offset onScreen(WidgetTester tester, String id) {
      final size = tester.getSize(find.byType(BattleView));
      return camera.view(size).project(world.drawn[id]! + Vector3(0, 3, 0))!;
    }

    testWidgets('COMBAT-11 a tap on an enemy targets it, and Fire shoots it', (
      tester,
    ) async {
      await play(tester);
      cubit.select('u-1');
      await settle(tester);

      expect(world.target, isNull);
      await tester.tapAt(onScreen(tester, 'r-near'));
      await settle(tester);

      expect(cubit.state.targetId, 'r-near');
      expect(find.text('Target: soldier'), findsOneWidget);
      // The world marks the target, so that the player sees which one it is.
      expect(world.target, 'r-near');
      expect(world.selected, 'u-1');

      await tester.tap(find.widgetWithText(TextButton, 'Fire'));
      await settle(tester);

      expect(host.orders, [const Fire(unitId: 'u-1', targetId: 'r-near')]);
      expect(find.textContaining('fire accepted'), findsOneWidget);
      // A tap on an enemy moves nothing.
      expect(host.orders.whereType<Move>(), isEmpty);
    });

    testWidgets('M7.5 the answer to an order shows with its own unit only', (
      tester,
    ) async {
      await play(tester);
      cubit
        ..select('u-1')
        ..target('r-near');
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Fire'));
      await settle(tester);
      expect(find.textContaining('fire accepted'), findsOneWidget);

      // The artillery is not the unit that fired.
      cubit.select('g-1');
      await settle(tester);
      expect(find.textContaining('fire accepted'), findsNothing);

      cubit.select('u-1');
      await settle(tester);
      expect(find.textContaining('fire accepted'), findsOneWidget);
    });

    testWidgets('COMBAT-11 the target is named in orange, from far away', (
      tester,
    ) async {
      await play(tester);
      cubit
        ..select('u-1')
        ..target('r-near');
      await settle(tester);

      // Far away, only the selected unit and the target are named.
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(400, 300),
          scrollDelta: Offset(0, 2000),
        ),
      );
      await tester.pump();

      expect(find.text('commander'), findsNothing);
      expect(find.text('artillery'), findsNothing);
      final names = tester.widgetList<Text>(find.text('soldier')).toList();
      expect(names, hasLength(2));
      final colors = names.map((name) => name.style?.color).toSet();
      expect(colors, {Colors.white, Colors.deepOrangeAccent});
    });

    testWidgets('COMBAT-11 fire needs a seen target: the button is off', (
      tester,
    ) async {
      await play(tester);
      cubit.select('u-1');
      await settle(tester);

      final fire = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Fire'),
      );

      expect(fire.enabled, isFalse);
      expect(find.text('No target in sight'), findsOneWidget);
    });

    testWidgets('COMBAT-12 fire at position, then tap the ground', (
      tester,
    ) async {
      await play(tester);
      cubit.select('g-1');
      await settle(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Fire at position'));
      await settle(tester);
      expect(cubit.state.groundFire, isTrue);
      expect(
        find.textContaining('Tap the ground to fire there'),
        findsOneWidget,
      );

      // Between the units panel above and the unit's panel below.
      await tester.tapAt(const Offset(600, 370));
      await settle(tester);

      final order = host.orders.single as FireAtPosition;
      expect(order.unitId, 'g-1');
      expect(host.orders.whereType<Move>(), isEmpty);
      expect(cubit.state.groundFire, isFalse);
      expect(find.textContaining('fire at position accepted'), findsOneWidget);
    });

    testWidgets('COMBAT-12 Escape gives up firing at a position first', (
      tester,
    ) async {
      await play(tester);
      cubit
        ..select('g-1')
        ..toggleGroundFire();
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(cubit.state.groundFire, isFalse);
      expect(cubit.state.selectedId, 'g-1');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(cubit.state.selectedId, isNull);
    });

    testWidgets(
      'COMBAT-14 aimed fire from first person sends FireAimed with the '
      "camera's direction",
      (tester) async {
        await play(tester);
        cubit.select('u-1');
        await settle(tester);
        expect(find.byType(AimReticle), findsNothing);

        await tester.tap(find.text('View from unit'));
        await settle(tester);
        expect(find.byType(AimReticle), findsOneWidget);
        // Look around a little, so that the aim is not the default one.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await settle(tester);
        await settle(tester);
        final forward = camera.forward.clone();

        await tester.tap(find.widgetWithText(TextButton, 'Fire'));
        await settle(tester);

        final order = host.orders.single as FireAimed;
        expect(order.unitId, 'u-1');
        expect(order.aim, directionOf(forward));
        expect(order.aim.z, greaterThan(0), reason: 'it looks up a little');
        expect(order.fireTime, greaterThanOrEqualTo(armedView.at));
      },
    );

    testWidgets('M7.5 the world draws the shots the section sees, no more', (
      tester,
    ) async {
      await play(tester);

      await hostSends(
        tester,
        TickUpdate(
          at: armedView.at + const Duration(seconds: 1),
          events: const [
            Attacked(
              attackerId: 'u-1',
              sectionId: 's-blue',
              weapon: 'rifle',
              hit: true,
              impacts: [
                Impact(
                  targetId: 'r-near',
                  targetType: 'soldier',
                  damage: 12,
                  friendly: false,
                  result: ImpactResult.damaged,
                ),
              ],
            ),
          ],
          // A hit by a shooter it does not see, on its commander.
          unseenHits: const [
            UnseenHit(targetId: 'c-1', damage: 5, result: ImpactResult.damaged),
          ],
          // The enemy fires at something unseen.
          fired: const [
            Fired(
              attackerId: 'r-near',
              sectionId: 's-red',
              weapon: 'rifle',
              shots: 2,
            ),
          ],
        ),
      );

      expect(world.shots, [
        const Tracer(
          from: Position(50500, 6000, 3000),
          to: Position(48500, 6000, 3000),
          weapon: 'rifle',
        ),
        const HitMark(
          at: Position(48500, 6000, 3000),
          result: ImpactResult.damaged,
        ),
        const MuzzleFlash(at: Position(48500, 6000, 3000), weapon: 'rifle'),
        const HitMark(
          at: Position(50500, 5500, 3000),
          result: ImpactResult.damaged,
        ),
      ]);
      // The hit on the commander has no shooter: no tracer ends at it, none
      // starts from anywhere else than the units the section sees.
      final tracers = world.shots.whereType<Tracer>();
      expect(
        tracers.map((tracer) => tracer.to),
        isNot(contains(blueCommander.position)),
      );
    });

    testWidgets('M7.5 a rebuild does not draw the same shot twice', (
      tester,
    ) async {
      await play(tester);
      await hostSends(
        tester,
        TickUpdate(
          at: armedView.at + const Duration(seconds: 1),
          unseenHits: const [
            UnseenHit(targetId: 'c-1', damage: 5, result: ImpactResult.damaged),
          ],
        ),
      );
      expect(world.shots, hasLength(1));

      // Selecting, targeting, a frame: the state changes, the shot does not
      // come back.
      cubit.select('u-1');
      await settle(tester);
      cubit.target('r-near');
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(world.shots, hasLength(1));
    });
  });
}
