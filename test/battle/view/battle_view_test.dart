import 'package:battle_map/battle_map.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/map_assets.dart';
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    testWidgets('shows where it stands, its help and the attribution', (
      tester,
    ) async {
      when(() => cubit.state)
          .thenReturn(_playing.copyWith(problem: 'the host is far'));
      await pump(tester);

      expect(find.textContaining('In battle'), findsOneWidget);
      expect(find.textContaining('blue · s-blue'), findsOneWidget);
      expect(find.textContaining('the host is far'), findsOneWidget);
      expect(find.textContaining('Drag to pan'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      expect(world.drawn.keys, unorderedEquals(['c-1', 'r-1']));
    });

    testWidgets('names the units close up, and moves on each frame', (
      tester,
    ) async {
      await pump(tester);
      tick(0.5);
      await tester.pump();

      expect(world.seconds, 0.5);
      expect(find.text('commander'), findsOneWidget);
    });

    testWidgets('selects a unit of its section, and lets it go', (
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

    testWidgets('moves the selected unit where the ground is tapped', (
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

    testWidgets('does nothing with the ground and no selection', (
      tester,
    ) async {
      await pump(tester);

      await tester.tapAt(const Offset(400, 500));
      // The sky.
      await tester.tapAt(const Offset(400, 2));

      verifyNever(() => cubit.moveSelectedTo(any()));
    });

    testWidgets('shows the selected unit and the answer to its order', (
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

    testWidgets('shows a refused order and an AP it does not know', (
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

    testWidgets("lists the section's units, and deploys a stored one", (
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
      'Centre looks at the section again, and selects from its list',
      (tester) async {
        await pump(tester);
        await tester.tap(find.text('Centre'));
        await tester.pump();

        expect(find.text('commander'), findsOneWidget);

        await tester.tap(find.textContaining('commander · in the field'));
        verify(() => cubit.select('c-1')).called(1);
      },
    );

    testWidgets('pans, zooms and turns with the mouse, fingers and keys', (
      tester,
    ) async {
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
    });
  });
}
