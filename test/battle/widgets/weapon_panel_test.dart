import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/widgets/weapon_panel.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';

class _MockBattleCubit extends MockCubit<BattleState> implements BattleCubit;

const _passed = PreCheckPassed();
const _now = Duration(hours: 1);

/// The rifleman, busy until [busyUntil].
UnitView _busy(Duration busyUntil) => UnitView(
  unitId: 'u-1',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: blueRifleman.position,
  weapon: 'rifle',
  private: UnitPrivate(
    sightRangeM: 60,
    place: UnitPlace.deployed,
    ap: blueRifleman.private!.ap,
    morale: 100,
    rounds: 4,
    xpEarned: 0,
    xpUnspent: 0,
    busyUntil: busyUntil,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Direction.of(0, 0, 0));
    registerFallbackValue(const Position(0, 0, 0));
    registerFallbackValue(blueRifleman);
  });

  group(WeaponPanel, () {
    late _MockBattleCubit cubit;

    setUp(() {
      cubit = _MockBattleCubit();
      when(() => cubit.state).thenReturn(
        const BattleState(
          status: BattleStatus.playing,
          units: {'u-1': blueRifleman, 'r-1': redSoldier},
          team: 'blue',
          sectionId: 's-blue',
          selectedId: 'u-1',
        ),
      );
      when(() => cubit.battleTime).thenReturn(_now);
      when(() => cubit.checkFire()).thenReturn(_passed);
      when(() => cubit.checkFireAimed()).thenReturn(_passed);
      when(() => cubit.checkFireAtPosition())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.notIndirect));
      when(() => cubit.checkReload()).thenReturn(_passed);
      when(() => cubit.checkSwap(any())).thenReturn(_passed);
      when(() => cubit.swappableWeapons).thenReturn(const []);
      when(() => cubit.magazineOf(any())).thenReturn(10);
      when(() => cubit.fireSelected()).thenAnswer((_) async {});
      when(() => cubit.fireAimed(any())).thenAnswer((_) async {});
      when(() => cubit.reload()).thenAnswer((_) async {});
      when(() => cubit.swap(any())).thenAnswer((_) async {});
      when(() => cubit.toggleGroundFire()).thenReturn(null);
    });

    Future<void> pump(
      WidgetTester tester, {
      UnitView? unit,
      Direction Function()? aim,
      Locale? locale,
    }) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<BattleCubit>.value(
            value: cubit,
            child: WeaponPanel(unit: unit ?? blueRifleman, aim: aim),
          ),
        ),
      ),
    );

    /// Whether the button labelled [label] can be pressed.
    bool enabled(WidgetTester tester, String label) => tester
        .widget<TextButton>(find.widgetWithText(TextButton, label))
        .enabled;

    testWidgets('M7.5 shows the weapon, its rounds and no reload under way', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Rifle · Rounds 10/10'), findsOneWidget);
      expect(find.textContaining('Busy'), findsNothing);
    });

    testWidgets('M7.5 shows a weapon busy being reloaded or swapped', (
      tester,
    ) async {
      await pump(tester, unit: _busy(_now + const Duration(seconds: 3)));

      expect(find.text('Rifle · Rounds 4/10 · Busy for 3 s'), findsOneWidget);
    });

    testWidgets('M7.5 shows no busy weapon once its time is up', (
      tester,
    ) async {
      await pump(tester, unit: _busy(_now));

      expect(find.text('Rifle · Rounds 4/10'), findsOneWidget);
    });

    testWidgets('M7.5 shows a magazine it has no size for', (tester) async {
      when(() => cubit.magazineOf(any())).thenReturn(null);

      await pump(tester);

      expect(find.text('Rifle · Rounds 10/?'), findsOneWidget);
    });

    testWidgets('UNIT-38 a unit with no weapon says so, and cannot fire', (
      tester,
    ) async {
      when(() => cubit.checkFire())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.noWeapon));
      when(() => cubit.checkReload())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.noWeapon));

      await pump(tester, unit: blueCommander);

      expect(find.text('No weapon'), findsNWidgets(2));
      expect(find.textContaining('Rounds'), findsNothing);
      expect(enabled(tester, 'Fire'), isFalse);
      expect(enabled(tester, 'Reload'), isFalse);
    });

    testWidgets('COMBAT-11 names the target, and fires at it', (tester) async {
      when(() => cubit.state).thenReturn(
        const BattleState(
          status: BattleStatus.playing,
          units: {'u-1': blueRifleman, 'r-1': redSoldier},
          team: 'blue',
          sectionId: 's-blue',
          selectedId: 'u-1',
          targetId: 'r-1',
        ),
      );

      await pump(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Fire'));

      expect(find.text('Target: soldier'), findsOneWidget);
      verify(() => cubit.fireSelected()).called(1);
    });

    testWidgets('COMBAT-11 fire needs a seen target: the button says why', (
      tester,
    ) async {
      when(() => cubit.checkFire())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.targetNotSeen));

      await pump(tester);

      expect(find.text('No target in sight'), findsOneWidget);
      expect(enabled(tester, 'Fire'), isFalse);
      expect(find.textContaining('Target:'), findsNothing);
    });

    testWidgets('COMBAT-11 an out of range target: the button says so', (
      tester,
    ) async {
      when(() => cubit.checkFire())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.outOfRange));

      await pump(tester);

      expect(find.text('Out of range'), findsOneWidget);
      expect(enabled(tester, 'Fire'), isFalse);
    });

    testWidgets('COMBAT-06 a shot short of AP says how long it waits', (
      tester,
    ) async {
      for (final (wait, text) in [
        (const Duration(seconds: 40), 'Waits 40 s for AP'),
        (const Duration(minutes: 45), 'Waits 45 min for AP'),
        (const Duration(hours: 1, minutes: 30), 'Waits 1.5 h for AP'),
      ]) {
        when(() => cubit.checkFire()).thenReturn(PreCheckPassed(apWait: wait));

        await pump(tester);
        await tester.pump();

        expect(find.text(text), findsOneWidget);
        // Waiting for AP is no refusal: the shot can be ordered.
        expect(enabled(tester, 'Fire'), isTrue);
      }
    });

    testWidgets('COMBAT-12 fire at position arms the next tap on the ground', (
      tester,
    ) async {
      when(() => cubit.checkFireAtPosition()).thenReturn(_passed);

      await pump(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Fire at position'));

      verify(() => cubit.toggleGroundFire()).called(1);
      expect(find.textContaining('Tap the ground'), findsNothing);
    });

    testWidgets('COMBAT-12 only indirect-fire units can fire at a position', (
      tester,
    ) async {
      await pump(tester);

      expect(enabled(tester, 'Fire at position'), isFalse);
    });

    testWidgets('COMBAT-12 says the next tap fires, while it is armed', (
      tester,
    ) async {
      when(() => cubit.checkFireAtPosition()).thenReturn(_passed);
      when(() => cubit.state).thenReturn(
        const BattleState(
          status: BattleStatus.playing,
          units: {'u-1': blueRifleman},
          sectionId: 's-blue',
          selectedId: 'u-1',
          groundFire: true,
        ),
      );

      await pump(tester);

      expect(
        find.textContaining('Tap the ground to fire there'),
        findsOneWidget,
      );
    });

    testWidgets('COMBAT-33 reloads', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Reload'));

      verify(() => cubit.reload()).called(1);
    });

    testWidgets('COMBAT-28 offers each spare weapon the unit may take', (
      tester,
    ) async {
      when(() => cubit.swappableWeapons).thenReturn(const ['machine_gun']);

      await pump(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Swap to Machine gun'));

      verify(() => cubit.swap('machine_gun')).called(1);
    });

    testWidgets(
      'COMBAT-28 away from the storage place it cannot swap, and says why',
      (tester) async {
        when(() => cubit.swappableWeapons).thenReturn(const ['machine_gun']);
        when(() => cubit.checkSwap(any()))
            .thenReturn(const PreCheckRefused(PreCheckRefusal.notAtStorage));

        await pump(tester);

        expect(enabled(tester, 'Swap to Machine gun'), isFalse);
        expect(find.text('Not next to the storage place'), findsOneWidget);
      },
    );

    testWidgets('COMBAT-14 from first person fires along the aim', (
      tester,
    ) async {
      final aim = Direction.of(0, -1, 0.1);
      when(() => cubit.checkFire())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.targetNotSeen));

      await pump(tester, aim: () => aim);
      await tester.tap(find.widgetWithText(TextButton, 'Fire'));

      // It asks about the aimed shot, not about a target.
      verify(() => cubit.fireAimed(aim)).called(1);
      verifyNever(() => cubit.fireSelected());
      expect(find.text('No target in sight'), findsNothing);
    });

    testWidgets('decision 183 artillery does not fly: no aimed fire', (
      tester,
    ) async {
      when(() => cubit.checkFireAimed())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.notAimed));

      await pump(tester, aim: () => Direction.of(0, -1, 0));

      expect(enabled(tester, 'Fire'), isFalse);
      expect(
        find.text('This weapon is not aimed from first person'),
        findsOneWidget,
      );
    });

    testWidgets('M7.5 says everything in French', (tester) async {
      when(() => cubit.swappableWeapons).thenReturn(const ['machine_gun']);
      when(() => cubit.checkFire())
          .thenReturn(const PreCheckRefused(PreCheckRefusal.outOfRange));

      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Fusil · Cartouches 10/10'), findsOneWidget);
      expect(find.text('Hors de portée'), findsOneWidget);
      for (final label in [
        'Tirer',
        'Tirer sur une position',
        'Recharger',
        'Prendre : Mitrailleuse',
      ]) {
        expect(find.widgetWithText(TextButton, label), findsOneWidget);
      }
    });
  });

  group(AimReticle, () {
    testWidgets('COMBAT-14 is a cross in the middle that takes no tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AimReticle())),
      );

      expect(find.byType(AimReticle), findsOneWidget);
      final centre = tester.getCenter(find.byType(AimReticle));
      expect(centre, tester.getCenter(find.byType(Scaffold)));
      final ignoring = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(AimReticle),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignoring.ignoring, isTrue);
    });
  });
}
