import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/world/top_down_camera.dart';
import 'package:battle_team/l10n/l10n.dart';
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
import '../../helpers/mocks.dart';

class _MockBattleCubit extends MockCubit<BattleState> implements BattleCubit;

const _playing = BattleState(
  status: BattleStatus.playing,
  units: {'c-1': blueCommander, 'r-1': redSoldier},
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  late MapData map;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    map = await loadMapAsset(rootBundle, 'saint_lo_1km');
    registerFallbackValue(const Position(0, 0, 0));
    registerFallbackValue(blueCommander);
  });

  group(BattleView, () {
    late _MockBattleCubit cubit;
    late FakeWorld world;
    late void Function(double) tick;

    setUp(() {
      cubit = _MockBattleCubit();
      world = FakeWorld(map);
      when(() => cubit.state).thenReturn(_playing);
      when(() => cubit.battleTime).thenReturn(const Duration(hours: 1));
      when(() => cubit.apNow(any())).thenReturn(30);
      when(() => cubit.moveSelectedTo(any())).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<BattleCubit>.value(
            value: cubit,
            child: BattleView(
              map: map,
              world: world,
              sceneBuilder: (context, world, camera, onTick) {
                tick = onTick;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
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

    testWidgets('M7.1 moves the selected unit where the ground is tapped', (
      tester,
    ) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(selectedId: () => 'c-1'));
      await pump(tester);

      await tester.tapAt(const Offset(400, 500));
      final to =
          verify(() => cubit.moveSelectedTo(captureAny())).captured.single
              as Position;
      expect(to.y, greaterThan(blueCommander.position!.y));

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

    testWidgets("M7.1 lists the section's units, and deploys a stored one", (
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
      when(() => cubit.deploy(any())).thenAnswer((_) async {});
      await pump(tester);

      expect(find.textContaining('commander · in the field'), findsOneWidget);
      expect(find.textContaining('soldier · stored'), findsOneWidget);
      expect(find.textContaining('soldier · in the field'), findsNothing);
      // Only the stored unit can be deployed.
      expect(find.text('Deploy'), findsOneWidget);

      await tester.tap(find.text('Deploy'));
      verify(() => cubit.deploy('s-1')).called(1);
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
      );
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
          home: BlocProvider<BattleCubit>.value(
            value: cubit,
            child: BattleView(
              map: map,
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
