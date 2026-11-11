import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:battle_team/battle/world/battle_camera.dart';
import 'package:battle_team/battle/world/first_person_camera.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../helpers/fake_host.dart';
import '../../helpers/fake_world.dart';
import '../../helpers/log_capture.dart';
import '../../helpers/mocks.dart';
import '../../helpers/pre_check.dart';
import '../../helpers/real_cubit.dart';
import '../../helpers/shop_cubit.dart';
import '../../helpers/storage_cubit.dart';

class _MockBattleCubit extends MockCubit<BattleState> implements BattleCubit;

const _playing = BattleState(
  status: BattleStatus.playing,
  units: {'c-1': blueCommander, 'r-1': redSoldier},
  team: 'blue',
  sectionId: 's-blue',
);

/// The section's commander 100 m from the north-west corner, and a soldier of
/// the section 50 m north of it: seen from the commander's eyes facing north,
/// the soldier is ahead.
final UnitView _eyesCommander = UnitView(
  unitId: 'c-1',
  unitType: 'commander',
  sectionId: 's-blue',
  team: 'blue',
  hp: 200,
  maxHp: 200,
  position: const Position(100000, 100000, 3000),
  private: blueCommander.private,
);

final UnitView _eyesSoldier = UnitView(
  unitId: 's-2',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: const Position(100000, 50000, 3000),
  private: blueCommander.private,
);

final BattleState _fromAbove = _playing.copyWith(
  units: {'c-1': _eyesCommander, 's-2': _eyesSoldier, 'r-1': redSoldier},
  selectedId: () => 'c-1',
);

final BattleState _fromCommander = _fromAbove.copyWith(
  viewMode: const FirstPersonMode('c-1'),
);

void main() {
  late MapData map;
  late UnitBodies bodies;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    map = await loadMapAsset(rootBundle, 'saint_lo_1km');
    bodies = await loadUnitBodies(rootBundle);
    registerFallbackValue(const Position(0, 0, 0));
    registerFallbackValue(blueCommander);
  });

  group(BattleView, () {
    late _MockBattleCubit cubit;
    late FakeWorld world;
    late void Function(double) tick;
    late BattleCamera sceneCamera;
    late StreamController<BattleState> states;
    late StreamController<BattleSnapshot> snapshots;
    late StorageCubit storage;
    late ShopCubit shop;

    setUp(() {
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      addTearDown(snapshots.close);
      storage = storageCubit(snapshots.stream);
      addTearDown(storage.close);
      shop = shopCubit(snapshots.stream);
      addTearDown(shop.close);
      cubit = _MockBattleCubit();
      world = FakeWorld(map);
      states = StreamController<BattleState>.broadcast();
      addTearDown(states.close);
      when(() => cubit.state).thenReturn(_playing);
      when(() => cubit.stream).thenAnswer((_) => states.stream);
      when(() => cubit.battleTime).thenReturn(const Duration(hours: 1));
      when(() => cubit.apNow(any())).thenReturn(30);
      when(() => cubit.moveSelectedTo(any())).thenAnswer((_) async {});
      when(() => cubit.previewMoveTo(any())).thenAnswer((_) async {});
      when(() => cubit.confirmMove()).thenAnswer((_) async {});
      // The weapon panel of M7.5 asks the cubit what the buttons may do; these
      // tests are about the view, so nothing may fire.
      when(() => cubit.shots).thenAnswer((_) => const Stream.empty());
      when(cubit.checkFire)
          .thenReturn(const PreCheckRefused(PreCheckRefusal.targetNotSeen));
      when(cubit.checkFireAimed)
          .thenReturn(const PreCheckRefused(PreCheckRefusal.noWeapon));
      when(cubit.checkFireAtPosition)
          .thenReturn(const PreCheckRefused(PreCheckRefusal.noWeapon));
      when(cubit.checkReload)
          .thenReturn(const PreCheckRefused(PreCheckRefusal.noWeapon));
      when(() => cubit.swappableWeapons).thenReturn(const []);
      when(() => cubit.magazineOf(any())).thenReturn(10);
    });

    Future<void> pump(
      WidgetTester tester, {
      Locale? locale,
      UnitBodies? unitBodies,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<StorageCubit>.value(value: storage),
              BlocProvider<ShopCubit>.value(value: shop),
              BlocProvider<BattleCubit>.value(value: cubit),
            ],
            child: BattleView(
              map: map,
              bodies: unitBodies ?? bodies,
              world: world,
              sceneBuilder: (context, world, camera, onTick) {
                tick = onTick;
                sceneCamera = camera;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// The cubit now holds [state]: the view hears of it and rebuilds.
    Future<void> show(WidgetTester tester, BattleState state) async {
      when(() => cubit.state).thenReturn(state);
      states.add(state);
      // The stream reaches the view's listener after the frame that was
      // pumped, so the rebuild it asks for needs a second one.
      await tester.pump();
      await tester.pump();
    }

    /// Where [unitId] shows, with the camera the view starts with: on the
    /// section's units, 120 m away.
    Offset onScreen(WidgetTester tester, String unitId) {
      final commander = world.drawn['c-1']!;
      final camera = TopDownCamera(target: commander, distance: 120);
      final size = tester.getSize(find.byType(BattleView));
      return camera
          .view(size)
          .project(world.drawn[unitId]! + Vector3(0, 3, 0))!;
    }

    testWidgets('M7.1 shows where it stands and its help', (tester) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(problem: 'the host is far'));
      await pump(tester);

      expect(find.textContaining('In battle'), findsOneWidget);
      expect(find.textContaining('blue · s-blue'), findsOneWidget);
      expect(find.textContaining('the host is far'), findsOneWidget);
      expect(find.textContaining('Drag to pan'), findsOneWidget);
      expect(world.drawn.keys, unorderedEquals(['c-1', 'r-1']));
    });

    testWidgets("Q-MAP-22 the credits entry shows the map's attribution", (
      tester,
    ) async {
      await pump(tester);
      // The attribution is behind the entry, not on the map.
      expect(find.textContaining('OpenStreetMap'), findsNothing);

      await tester.tap(find.text('Credits'));
      await tester.pumpAndSettle();

      expect(map.spec.attribution, isNotEmpty);
      for (final line in map.spec.attribution) {
        expect(find.textContaining(line), findsOneWidget);
      }

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.textContaining('OpenStreetMap'), findsNothing);
    });

    testWidgets(
      'decision 236 hands the battle time to the world, which glides the '
      'units to their destination',
      (tester) async {
        await pump(tester);

        expect(world.battleTime, const Duration(hours: 1));
      },
    );

    testWidgets('M7.1 names the units close up, and moves on each frame', (
      tester,
    ) async {
      await pump(tester);
      tick(0.5);
      await tester.pump();

      expect(world.seconds, 0.5);
      expect(find.text('commander'), findsOneWidget);
    });

    testWidgets('M7.1 selects a unit of its section, and lets it go', (
      tester,
    ) async {
      await pump(tester);

      await tester.tapAt(onScreen(tester, 'c-1'));
      verify(() => cubit.select('c-1')).called(1);

      when(() => cubit.state)
          .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
      await tester.tapAt(onScreen(tester, 'c-1'));
      verify(() => cubit.select(null)).called(1);
    });

    testWidgets('M7.8 a tap on the ground previews the selected unit move; '
        'nothing is sent by it', (tester) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
      await pump(tester);

      await tester.tapAt(const Offset(600, 500));
      final to =
          verify(() => cubit.previewMoveTo(captureAny())).captured.single
              as Position;
      expect(to.y, greaterThan(blueCommander.position!.y));

      verifyNever(() => cubit.moveSelectedTo(any()));
      verifyNever(() => cubit.select(any()));
    });

    testWidgets('M7.8 a previewed move is drawn as a line, shows its cost, '
        'and confirms or cancels', (tester) async {
      const points = [Position(50500, 5500, 3000), Position(52500, 5500, 3000)];
      final pending = PendingMove(
        unitId: 'c-1',
        from: blueCommander.position!,
        plan: const MovePreview(
          destination: Position(52500, 5500, 3000),
          cells: [Cell(5, 0), Cell(7, 0)],
          points: points,
          costAp: 20,
          lengthM: 20,
          arrivesAt: Duration(hours: 1, seconds: 4),
          apWait: Duration.zero,
        ),
      );
      when(() => cubit.state).thenReturn(
        _playing.copyWith(selectedId: () => 'c-1', pendingMove: () => pending),
      );
      await pump(tester);

      expect(world.path, points);
      expect(find.text('Move: 20 AP of 30 · arrives in 4 s'), findsOneWidget);

      await tester.tap(find.text('Confirm move'));
      verify(() => cubit.confirmMove()).called(1);
      await tester.tap(find.text('Cancel'));
      verify(() => cubit.cancelMove()).called(1);

      // The preview over, the line goes.
      await show(tester, _playing.copyWith(selectedId: () => 'c-1'));
      expect(world.path, isNull);
      expect(find.text('Confirm move'), findsNothing);
    });

    testWidgets('M7.8 the preview of another unit is not shown with the '
        'selected one, nor the arrival note of another', (tester) async {
      when(() => cubit.state).thenReturn(
        _playing.copyWith(
          selectedId: () => 'c-1',
          pendingMove: () => const PendingMove(
            unitId: 's-2',
            from: Position(0, 0, 0),
            plan: MoveRefused(PreCheckRefusal.noPath),
          ),
          arrivalNote: () => const ArrivalNote(
            unitId: 's-2',
            expected: Duration.zero,
            host: Duration(minutes: 1),
          ),
        ),
      );
      await pump(tester);

      expect(find.textContaining('Cannot move there'), findsNothing);
      expect(find.textContaining('The host has the unit arrive'), findsNothing);
    });

    testWidgets('M7.8 Escape gives up a previewed move before it clears the '
        'selection', (tester) async {
      when(() => cubit.state).thenReturn(
        _playing.copyWith(
          selectedId: () => 'c-1',
          pendingMove: () => const PendingMove(
            unitId: 'c-1',
            from: Position(0, 0, 0),
            plan: MoveRefused(PreCheckRefusal.noPath),
          ),
        ),
      );
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      verify(() => cubit.cancelMove()).called(1);
      verifyNever(() => cubit.select(any()));
    });

    testWidgets('M7.1 does nothing with the ground and no selection', (
      tester,
    ) async {
      await pump(tester);

      await tester.tapAt(const Offset(400, 500));
      // The sky.
      await tester.tapAt(const Offset(400, 2));

      verifyNever(() => cubit.moveSelectedTo(any()));
      verifyNever(() => cubit.previewMoveTo(any()));
    });

    testWidgets('M7.1 shows the selected unit and the answer to its order', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        _playing.copyWith(
          selectedId: () => 'c-1',
          notice: () => const OrderNotice(order: 'move', unitId: 'c-1'),
        ),
      );
      await pump(tester);

      expect(
        find.textContaining('commander · HP 200 · AP 30.0'),
        findsOneWidget,
      );
      expect(find.textContaining('move accepted'), findsOneWidget);
    });

    testWidgets('M7.1 shows a refused order and an AP it does not know', (
      tester,
    ) async {
      when(() => cubit.apNow(any())).thenReturn(null);
      when(() => cubit.state).thenReturn(
        _playing.copyWith(
          selectedId: () => 'c-1',
          notice: () => const OrderNotice(
            order: 'move',
            unitId: 'c-1',
            refusal: 'not_enough_ap',
          ),
        ),
      );
      await pump(tester);

      expect(find.textContaining('AP –'), findsOneWidget);
      expect(
        find.textContaining('move refused: not_enough_ap'),
        findsOneWidget,
      );
    });

    testWidgets("M7.1 lists the section's units, deployed or stored", (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        _playing.copyWith(
          units: {
            'c-1': blueCommander,
            's-1': storedSoldier,
            'r-1': redSoldier,
          },
        ),
      );
      await pump(tester);

      expect(find.textContaining('commander · in the field'), findsOneWidget);
      expect(find.textContaining('soldier · stored'), findsOneWidget);
      expect(find.textContaining('soldier · in the field'), findsNothing);
      // Deploying moved to the storage view (M7.6).
      expect(find.text('Deploy'), findsNothing);
    });

    testWidgets('M7.6 the Storage button opens the storage view, where a '
        'stored unit deploys, and closes it', (tester) async {
      await pump(tester);
      snapshots.add(
        const BattleSnapshot(
          units: {'c-1': blueCommander, 's-1': storedSoldier},
          hqs: [
            HqView(
              team: 'blue',
              position: Position(50500, 5500, 3000),
              hp: 1000,
              maxHp: 1000,
            ),
          ],
          relics: [],
          section: SectionPrivate(money: 0, xp: 0),
          team: 'blue',
          sectionId: 's-blue',
        ),
      );
      // The cubit lives in the real zone: let its stream deliver.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.text('Storage (1)'), findsOneWidget);
      expect(find.text('Deploy'), findsNothing);

      await tester.tap(find.text('Storage (1)'));
      await tester.pump();
      expect(find.text('Deploy'), findsOneWidget);
      expect(find.textContaining('Deploying costs 10 AP'), findsOneWidget);

      await tester.tap(find.text('Deploy'));
      await tester.pump();
      expect(find.textContaining('deploy accepted'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      expect(find.text('Deploy'), findsNothing);
    });

    testWidgets('M7.7 the Shop button opens the shop, which lists what the '
        'host lets the section buy; Storage and Shop take turns', (
      tester,
    ) async {
      await pump(tester);
      snapshots.add(
        const BattleSnapshot(
          units: {'c-1': blueCommander, 's-1': storedSoldier},
          hqs: [
            HqView(
              team: 'blue',
              position: Position(50500, 5500, 3000),
              hp: 1000,
              maxHp: 1000,
            ),
          ],
          relics: [],
          section: SectionPrivate(money: 500, xp: 0),
          roster: shopRoster,
          team: 'blue',
          sectionId: 's-blue',
        ),
      );
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Money: 500 w€'), findsNothing);

      await tester.tap(find.text('Shop'));
      await tester.pump();
      expect(find.text('Money: 500 w€'), findsOneWidget);
      expect(find.text('Soldier · 100 w€'), findsOneWidget);
      // No unit selected: the weapons wait for one.
      expect(
        find.text('Select one of your units to see the weapons it can use.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Storage (1)'));
      await tester.pump();
      expect(find.text('Money: 500 w€'), findsNothing);
      expect(find.text('Deploy'), findsOneWidget);

      await tester.tap(find.text('Shop'));
      await tester.pump();
      expect(find.text('Deploy'), findsNothing);
      await tester.tap(find.text('Buy').first);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('unit purchase accepted'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      expect(find.text('Money: 500 w€'), findsNothing);
    });

    testWidgets('M7.7 with a unit selected the shop lists the weapons it '
        'uses', (tester) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
      await pump(tester);
      snapshots.add(
        const BattleSnapshot(
          units: {'c-1': blueCommander},
          hqs: [],
          relics: [],
          section: SectionPrivate(money: 500, xp: 0),
          roster: Roster(
            units: [
              RosterUnit(
                unitType: 'commander',
                category: 'commander',
                price: 0,
                weapons: ['rifle'],
              ),
            ],
            weapons: [RosterWeapon(weapon: 'rifle', price: 100)],
          ),
          team: 'blue',
          sectionId: 's-blue',
        ),
      );
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      await tester.tap(find.text('Shop'));
      await tester.pump();

      expect(find.text('Weapons for Commander'), findsOneWidget);
      expect(find.text('Rifle · 100 w€'), findsOneWidget);
    });

    testWidgets('M7.6 the selected unit on the field has a store button', (
      tester,
    ) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
      await pump(tester);

      expect(find.textContaining('Recall'), findsOneWidget);
    });

    testWidgets(
      'M7.1 Centre looks at the section again, and selects from its list',
      (tester) async {
        await pump(tester);
        await tester.tap(find.text('Centre'));
        await tester.pump();

        expect(find.text('commander'), findsOneWidget);

        await tester.tap(find.textContaining('commander · in the field'));
        verify(() => cubit.select('c-1')).called(1);
      },
    );

    testWidgets(
      'decision 5 pans, zooms and turns the top-down view with the mouse, '
      'fingers and keys',
      (tester) async {
        when(() => cubit.state)
            .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
        await pump(tester);

        await tester.dragFrom(const Offset(400, 300), const Offset(50, 0));
        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(400, 300),
            scrollDelta: Offset(0, 100),
          ),
        );
        for (final key in [
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.keyQ,
          LogicalKeyboardKey.keyE,
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.keyZ,
        ]) {
          await tester.sendKeyEvent(key);
        }
        // Far away, only the selected unit is named.
        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(400, 300),
            scrollDelta: Offset(0, 2000),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);

        verify(() => cubit.select(null)).called(1);
        expect(find.text('commander'), findsOneWidget);
        expect(find.text('soldier'), findsNothing);
      },
    );
    group('seen from a unit', () {
      FirstPersonCamera eyes() => world.camera! as FirstPersonCamera;

      /// Plays from above, then enters the commander's eyes.
      Future<void> enter(WidgetTester tester) async {
        when(() => cubit.state).thenReturn(_fromAbove);
        await pump(tester);
        await show(tester, _fromCommander);
      }

      testWidgets(
        'decision 5 sees through the eyes of the unit the state names, and '
        'goes back to the camera it left',
        (tester) async {
          when(() => cubit.state).thenReturn(_fromAbove);
          await pump(tester);
          final above = world.camera;
          expect(above, isA<TopDownCamera>());
          expect(sceneCamera, same(above));

          await show(tester, _fromCommander);

          expect(eyes().unitId, 'c-1');
          expect(sceneCamera, same(world.camera));
          expect(sceneCamera.insideUnit, 'c-1');

          await show(tester, _fromAbove);

          expect(world.camera, same(above));
          expect(sceneCamera, same(above));
          expect(sceneCamera.insideUnit, isNull);
        },
      );

      testWidgets(
        'decision 235 the eye sits at the top of the unit hit volume, where '
        'the unit is drawn, and follows it',
        (tester) async {
          await enter(tester);
          final height = bodies.eyeHeightOf('commander')!;
          final feet = world.drawn['c-1']!;

          expect(eyes().eyeHeightM, height);
          expect(eyes().position.y, closeTo(feet.y + height, 1e-5));
          expect(eyes().position.x, feet.x);
          expect(eyes().position.z, feet.z);

          // The unit glides: the eyes go where it is drawn on each frame.
          world.drawn['c-1'] = Vector3(feet.x + 5, feet.y + 1, feet.z - 5);
          tick(0.1);
          await tester.pump();

          expect(eyes().position.x, feet.x + 5);
          expect(eyes().position.y, closeTo(feet.y + 1 + height, 1e-5));
          expect(eyes().position.z, feet.z - 5);
        },
      );

      testWidgets('decision 237 entering first person draws the same units as '
          'top-down', (tester) async {
        when(() => cubit.state).thenReturn(_fromAbove);
        await pump(tester);
        final before = {...world.drawn};
        expect(before.keys, unorderedEquals(['c-1', 's-2', 'r-1']));

        await show(tester, _fromCommander);
        expect(world.drawn, before);

        await show(tester, _fromAbove);
        expect(world.drawn, before);

        // Another section's unit the section stops seeing is not drawn
        // from the eyes either.
        await show(
          tester,
          _fromCommander.copyWith(
            units: {'c-1': _eyesCommander, 's-2': _eyesSoldier},
          ),
        );
        expect(world.drawn.keys, unorderedEquals(['c-1', 's-2']));
      });

      testWidgets('decision 5 faces where the overview faced', (tester) async {
        when(() => cubit.state).thenReturn(_fromAbove);
        await pump(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);

        await show(tester, _fromCommander);

        expect(eyes().yaw, closeTo(30 * 3.141592653589793 / 180, 1e-9));
        expect(eyes().pitch, 0);
      });

      testWidgets('decision 5 looks around with a drag, the arrows and Q/E', (
        tester,
      ) async {
        await enter(tester);

        await tester.dragFrom(const Offset(400, 300), const Offset(100, -40));
        await tester.pump();
        final dragged = eyes().yaw;
        // The touch slop takes the first pixels of the drag.
        expect(dragged, inInclusiveRange(0.3, 0.5));
        expect(eyes().pitch, greaterThan(0));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(eyes().yaw, greaterThan(dragged));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        expect(eyes().yaw, closeTo(dragged, 1e-9));
        final level = eyes().pitch;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(eyes().pitch, lessThan(level));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        expect(eyes().pitch, closeTo(level, 1e-9));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
        expect(eyes().yaw, closeTo(dragged, 1e-9));
      });

      testWidgets(
        'decision 5 does not zoom or pan the overview from a unit, and '
        'ignores the other keys',
        (tester) async {
          await enter(tester);
          final above = world.cameras.first as TopDownCamera;
          final distance = above.distance;
          final target = above.target.clone();
          final yaw = eyes().yaw;

          await tester.sendEventToBinding(
            const PointerScrollEvent(
              position: Offset(400, 300),
              scrollDelta: Offset(0, 100),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.equal);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.pump();

          expect(above.distance, distance);
          expect(above.target, target);
          expect(eyes().yaw, yaw);
        },
      );

      testWidgets('decision 5 Escape goes back above and keeps the unit', (
        tester,
      ) async {
        when(() => cubit.leaveFirstPerson()).thenReturn(null);
        await enter(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);

        verify(() => cubit.leaveFirstPerson()).called(1);
        verifyNever(() => cubit.select(any()));
      });

      testWidgets(
        'decision 5 a tap on the ground orders the same move from the eyes',
        (tester) async {
          await enter(tester);

          // Below the horizon, ahead of the eyes, above the panels.
          await tester.tapAt(const Offset(400, 360));

          final to =
              verify(() => cubit.moveSelectedTo(captureAny())).captured.single
                  as Position;
          expect(to.y, lessThan(_eyesCommander.position!.y));
          expect((to.x - _eyesCommander.position!.x).abs(), lessThan(5000));

          // The sky is no ground.
          await tester.tapAt(const Offset(400, 2));
          verifyNever(() => cubit.moveSelectedTo(any()));
        },
      );

      testWidgets(
        'decision 5 a tap on another unit of the section selects it, and '
        'a tap where the unit stands selects nothing',
        (tester) async {
          await enter(tester);
          final view = world.camera!.view(
            tester.getSize(find.byType(BattleView)),
          );

          final soldier = view.project(world.drawn['s-2']! + Vector3(0, 3, 0))!;
          await tester.tapAt(soldier);
          verify(() => cubit.select('s-2')).called(1);
          // The unit the eyes are in is not picked from inside.
          verifyNever(() => cubit.select('c-1'));
        },
      );

      testWidgets('M7.4 names the units in sight, not the unit it looks from', (
        tester,
      ) async {
        await enter(tester);

        // The soldier of the section and the red one are in sight.
        expect(find.text('soldier'), findsNWidgets(2));
        expect(find.text('commander'), findsNothing);
      });

      testWidgets(
        'M7.4 the unit panel offers the view from the unit and the way back',
        (tester) async {
          when(() => cubit.enterFirstPerson()).thenReturn(null);
          when(() => cubit.leaveFirstPerson()).thenReturn(null);
          when(() => cubit.state).thenReturn(_fromAbove);
          await pump(tester);

          expect(find.text('Top-down view'), findsNothing);
          await tester.tap(find.text('View from unit'));
          verify(() => cubit.enterFirstPerson()).called(1);

          await show(tester, _fromCommander);

          expect(find.text('View from unit'), findsNothing);
          // The AP between updates stays on the unit panel.
          expect(find.textContaining('AP 30.0'), findsOneWidget);
          expect(find.textContaining('Drag to look'), findsOneWidget);
          expect(find.textContaining('Drag to pan'), findsNothing);
          await tester.tap(find.text('Top-down view'));
          verify(() => cubit.leaveFirstPerson()).called(1);
        },
      );

      testWidgets('M7.4 offers no view from a unit that is not on the field', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          _fromAbove.copyWith(
            units: {'s-1': storedSoldier, 'r-1': redSoldier},
            selectedId: () => 's-1',
          ),
        );
        await pump(tester);

        expect(find.textContaining('soldier · HP 100'), findsOneWidget);
        expect(find.text('View from unit'), findsNothing);
        expect(find.text('Top-down view'), findsNothing);
      });

      testWidgets('M7.4 the buttons and the help are in French', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(_fromAbove);
        await pump(tester, locale: const Locale('fr'));
        expect(find.text("Vue depuis l'unité"), findsOneWidget);
        expect(find.textContaining('Glisser pour déplacer'), findsOneWidget);

        await show(tester, _fromCommander);

        expect(find.text('Vue de dessus'), findsOneWidget);
        expect(find.textContaining('Glisser pour regarder'), findsOneWidget);
      });

      testWidgets('M7.4 stays above for a unit type the app has no body for', (
        tester,
      ) async {
        final log = LogCapture();
        addTearDown(log.cancel);
        when(() => cubit.leaveFirstPerson()).thenReturn(null);
        when(() => cubit.state).thenReturn(_fromAbove);
        await pump(tester, unitBodies: const UnitBodies({}));

        await show(tester, _fromCommander);

        verify(() => cubit.leaveFirstPerson()).called(1);
        expect(world.camera, isA<TopDownCamera>());
        expect(sceneCamera, isA<TopDownCamera>());
        expect(log.lines, [
          'WARNING first person unavailable: no body for the unit type',
        ]);
        // Decision 237: the record names no unit.
        expect(log.texts.single, isNot(contains('c-1')));
        expect(log.texts.single, isNot(contains('commander')));
      });
    });
  });

  group('$BattleView over a recorded stream', () {
    testWidgets('decision 237 draws and lists only what the section sees', (
      tester,
    ) async {
      // Section 2 in clear weather, and in fog: fog hides some of what the
      // host showed it.
      final clear = FakeHost.recorded('clear_s-2_host').view;
      final fog = FakeHost.recorded('fog_s-2_host').view;
      final seen = {for (final unit in fog.units) unit.unitId};
      final hidden = {
        for (final unit in clear.units)
          if (!seen.contains(unit.unitId)) unit.unitId,
      };
      expect(hidden, isNotEmpty, reason: 'the recordings must differ');

      final apiClient = MockAppwriteApiClient();
      when(
        () => apiClient.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(apiClient.createJwt).thenAnswer((_) async => 'jwt');
      final host = FakeHost.recorded('fog_s-2');
      final cubit = BattleCubit(
        repository: BattleRepository(
          settings: const BattleSettings(
            endpoint: 'http://127.0.0.1:9/v1',
            projectId: 'hawkbee',
            email: 'a@battleteam.local',
            password: 'secret',
            battleId: 'b-1',
          ),
          apiClient: apiClient,
          transport: host,
          address: (_) async => Uri.parse('ws://host/v1/socket'),
        ),
        preCheck: testPreCheck(),
      );
      final storage = realStorageCubit(cubit);
      addTearDown(storage.close);
      addTearDown(cubit.close);
      await tester.runAsync(() async {
        await cubit.start();
        await pumpEventQueue(times: 500);
      });
      final world = FakeWorld(map);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<StorageCubit>.value(value: storage),
              BlocProvider<BattleCubit>.value(value: cubit),
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
      await tester.pump();

      expect(cubit.state.status, BattleStatus.playing);
      expect(world.drawn.keys, isNotEmpty);
      expect(world.drawn.keys.toSet().difference(seen), isEmpty);
      expect(world.drawn.keys.toSet().intersection(hidden), isEmpty);
      // The list names the section's own units and no other.
      expect(
        find.textContaining(RegExp('in the field|stored')),
        findsNWidgets(
          fog.units.where((unit) => unit.sectionId == host.sectionId).length,
        ),
      );
    });
  });
}
