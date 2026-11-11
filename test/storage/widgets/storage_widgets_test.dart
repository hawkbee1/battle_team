import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:battle_team/storage/widgets/storage_panel.dart';
import 'package:battle_team/storage/widgets/store_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/helpers.dart';
import '../../helpers/storage_cubit.dart';

const _hq = HqView(
  team: 'blue',
  position: Position(50500, 5500, 3000),
  hp: 1000,
  maxHp: 1000,
);

UnitView _stored(String id, {double ap = 30, double apMax = 30}) => UnitView(
  unitId: id,
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 80,
  maxHp: 100,
  private: UnitPrivate(
    sightRangeM: 60,
    place: UnitPlace.stored,
    ap: ApView(value: ap, at: const Duration(hours: 1), perHour: 1, max: apMax),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

/// A blue soldier in the field [metres] metres east of the HQ.
UnitView _field(String id, double metres, {String type = 'soldier'}) =>
    UnitView(
      unitId: id,
      unitType: type,
      sectionId: 's-blue',
      team: 'blue',
      hp: 100,
      maxHp: 100,
      position: Position(50500 + (metres * 100).round(), 5500, 3000),
      weapon: 'rifle',
      private: blueRifleman.private,
    );

UnitView _red(double metres) => UnitView(
  unitId: 'r-1',
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position(50500 + (metres * 100).round(), 5500, 3000),
);

BattleSnapshot _snapshot(
  List<UnitView> units, {
  SectionPrivate section = const SectionPrivate(money: 0, xp: 0),
  Map<String, Duration> recalls = const {},
  List<HqView> hqs = const [_hq],
}) => BattleSnapshot(
  units: {for (final unit in units) unit.unitId: unit},
  hqs: hqs,
  relics: const [],
  section: section,
  recalls: recalls,
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group('storage widgets', () {
    late MockBattleRepository repository;
    late StreamController<BattleSnapshot> snapshots;
    late StorageCubit cubit;
    var closed = false;

    setUp(() {
      closed = false;
      repository = MockBattleRepository();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      cubit = storageCubit(snapshots.stream, repository: repository);
    });

    tearDown(() async {
      await cubit.close();
      await snapshots.close();
    });

    /// Shows [child] over [cubit], after the section saw [snapshot].
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      required BattleSnapshot snapshot,
      Locale? locale,
    }) async {
      snapshots.add(snapshot);
      await tester.runAsync(pumpEventQueue);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<StorageCubit>.value(
              value: cubit,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Lets the cubit's order reach the repository and the answer come back.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    }

    group(StoragePanel, () {
      Widget panel() => StoragePanel(onClose: () => closed = true);

      testWidgets('HQ-33 lists a stored unit with its cost and deploys it', (
        tester,
      ) async {
        await pump(tester, panel(), snapshot: _snapshot([_stored('s-1')]));

        expect(find.text('Storage'), findsOneWidget);
        expect(find.textContaining('Portal: the HQ'), findsOneWidget);
        expect(find.text('Deploying costs 10 AP'), findsOneWidget);
        expect(find.text('soldier · HP 80/100 · AP 30.0'), findsOneWidget);
        expect(find.text('No unit in storage'), findsNothing);

        await tester.tap(find.text('Deploy'));
        await settle(tester);

        verify(() => repository.send(const Deploy(unitId: 's-1'))).called(1);
        expect(find.text('deploy accepted'), findsOneWidget);
      });

      testWidgets('HQ-33 an empty storage says so', (tester) async {
        await pump(tester, panel(), snapshot: _snapshot([blueCommander]));

        expect(find.text('No unit in storage'), findsOneWidget);
        expect(find.text('Deploy'), findsNothing);
      });

      testWidgets('HQ-29 shows only the section own stored units', (
        tester,
      ) async {
        const other = UnitView(
          unitId: 'x-1',
          unitType: 'artillery',
          sectionId: 's-green',
          team: 'blue',
          hp: 100,
          maxHp: 100,
        );
        await pump(
          tester,
          panel(),
          snapshot: _snapshot([_stored('s-1'), other, redSoldier]),
        );

        expect(find.textContaining('soldier · HP'), findsOneWidget);
        expect(find.textContaining('artillery'), findsNothing);
        expect(find.text('Deploy'), findsOneWidget);
      });

      testWidgets('HQ-35 a locked section shows the lock and disables deploy', (
        tester,
      ) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_stored('s-1')],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              lockedUntil: Duration(hours: 24, minutes: 30),
            ),
          ),
        );

        expect(
          find.text('Locked for 23.5 h: no unit can deploy'),
          findsOneWidget,
        );
        expect(find.text('The section is locked'), findsOneWidget);
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Deploy'),
        );
        expect(button.onPressed, isNull);

        await tester.tap(find.text('Deploy'), warnIfMissed: false);
        await settle(tester);
        verifyNever(() => repository.send(any()));
      });

      testWidgets('HQ-35 the lock counts down with the battle time', (
        tester,
      ) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_stored('s-1')],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              lockedUntil: Duration(hours: 3),
            ),
          ),
        );
        expect(find.text('Locked for 2.0 h: no unit can deploy'), findsOne);

        when(() => repository.battleTime)
            .thenReturn(const Duration(hours: 2, minutes: 30));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Locked for 30 min: no unit can deploy'), findsOne);

        when(() => repository.battleTime).thenReturn(const Duration(hours: 3));
        await tester.pump(const Duration(seconds: 1));

        expect(find.textContaining('Locked for'), findsNothing);
        final button = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Deploy'),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('HQ-36 an enemy within 20 m shows blocked', (tester) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot([_stored('s-1'), _red(15)]),
        );

        expect(
          find.text('Blocked: an enemy is within 20 m of the portal'),
          findsOneWidget,
        );
        expect(find.text('An enemy is near the portal'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Deploy'))
              .onPressed,
          isNull,
        );
      });

      testWidgets('decision 237 an enemy the section does not see shows no '
          "block; the host's refusal shows as the host's", (tester) async {
        when(() => repository.send(any()))
            .thenAnswer((_) async => 'blocked_by_enemy');
        await pump(tester, panel(), snapshot: _snapshot([_stored('s-1')]));

        expect(find.textContaining('Blocked'), findsNothing);

        await tester.tap(find.text('Deploy'));
        await settle(tester);

        expect(
          find.text('deploy refused: An enemy is near the portal'),
          findsOneWidget,
        );
      });

      testWidgets('HQ-33 a unit short of AP waits for them, button on', (
        tester,
      ) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot([_stored('s-1', ap: 4)]),
        );

        expect(find.text('Waits 6.0 h for AP'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Deploy'))
              .onPressed,
          isNotNull,
        );
      });

      testWidgets('HQ-33 a unit whose pool never holds the cost is refused', (
        tester,
      ) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot([_stored('s-1', ap: 5, apMax: 5)]),
        );

        expect(
          find.text('A shot costs more AP than the unit can hold'),
          findsOneWidget,
        );
      });

      testWidgets('HQ-32 lists the recalls on their way', (tester) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_field('u-1', 100)],
            recalls: {'u-1': const Duration(hours: 4)},
          ),
        );

        expect(find.text('Recalls in progress'), findsOneWidget);
        expect(find.text('soldier: stored in 3.0 h'), findsOneWidget);
      });

      testWidgets('HQ-37 lists the prisoners the section holds', (
        tester,
      ) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_stored('s-1')],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              prisoners: [
                JoinedUnit(unitId: 'r-8', unitType: 'sniper'),
                JoinedUnit(unitId: 'r-9', unitType: 'artillery'),
              ],
            ),
          ),
        );

        expect(find.text('Prisoners (2)'), findsOneWidget);
        expect(find.text('sniper'), findsOneWidget);
        expect(find.text('artillery'), findsOneWidget);
      });

      testWidgets('a portal the section does not see is said', (tester) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot([_stored('s-1')], hqs: const []),
        );

        expect(find.text('The portal is not in sight'), findsOneWidget);
      });

      testWidgets('closes', (tester) async {
        await pump(tester, panel(), snapshot: _snapshot([_stored('s-1')]));

        await tester.tap(find.text('Close'));

        expect(closed, isTrue);
      });

      testWidgets('is read by a screen reader: headers and labelled buttons', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_stored('s-1')],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              prisoners: [JoinedUnit(unitId: 'r-8', unitType: 'sniper')],
            ),
          ),
        );

        expect(
          tester.getSemantics(find.text('Storage')),
          matchesSemantics(label: 'Storage', isHeader: true),
        );
        expect(find.bySemanticsLabel('Deploy soldier'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Deploy soldier')),
          matchesSemantics(
            label: 'Deploy soldier',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        expect(find.bySemanticsLabel('Prisoners (1)'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('is in French', (tester) async {
        await pump(
          tester,
          panel(),
          snapshot: _snapshot(
            [_stored('s-1'), _red(5)],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              lockedUntil: Duration(hours: 5),
            ),
          ),
          locale: const Locale('fr'),
        );

        expect(find.text('Réserve'), findsOneWidget);
        expect(find.text('Déployer'), findsOneWidget);
        expect(find.text('Déployer coûte 10 PA'), findsOneWidget);
        expect(
          find.text(
            'Verrouillée pour 4.0 h : aucune unité ne peut se déployer',
          ),
          findsOneWidget,
        );
        expect(find.text('Fermer'), findsOneWidget);
      });
    });

    group(StoreButton, () {
      Widget button(UnitView unit) => StoreButton(unit: unit);

      testWidgets('HQ-31 next to the portal it stores at once', (tester) async {
        final unit = _field('u-1', 5);
        await pump(tester, button(unit), snapshot: _snapshot([unit]));

        expect(find.text('Store now'), findsOneWidget);

        await tester.tap(find.text('Store now'));
        await settle(tester);

        verify(() => repository.send(const Store(unitId: 'u-1'))).called(1);
        expect(find.text('store accepted'), findsOneWidget);
      });

      testWidgets('HQ-32 from afar it shows the recall time, then recalls', (
        tester,
      ) async {
        final unit = _field('u-1', 100);
        await pump(tester, button(unit), snapshot: _snapshot([unit]));

        expect(find.text('Recall (6.0 h)'), findsOneWidget);

        await tester.tap(find.text('Recall (6.0 h)'));
        await settle(tester);

        verify(() => repository.send(const Recall(unitId: 'u-1'))).called(1);
        expect(find.text('recall accepted'), findsOneWidget);
      });

      testWidgets('HQ-32 a recall that runs says when the unit is stored', (
        tester,
      ) async {
        final unit = _field('u-1', 100);
        await pump(
          tester,
          button(unit),
          snapshot: _snapshot(
            [unit],
            recalls: {'u-1': const Duration(hours: 4)},
          ),
        );

        expect(find.text('Recalled: stored in 3.0 h'), findsOneWidget);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
      });

      testWidgets('HQ-30 a unit never stored says why', (tester) async {
        final unit = _field('e-1', 5, type: 'encampment');
        await pump(tester, button(unit), snapshot: _snapshot([unit]));

        expect(find.text('This unit is never stored'), findsOneWidget);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
      });

      testWidgets("M7.6 shows the host's refusal of an order for its unit "
          'only', (tester) async {
        when(() => repository.send(any()))
            .thenAnswer((_) async => 'not_at_storage');
        final unit = _field('u-1', 5);
        final other = _field('u-2', 5);
        await pump(tester, button(other), snapshot: _snapshot([unit, other]));

        await tester.runAsync(() => cubit.storeOrRecall('u-1'));
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(find.textContaining('refused'), findsNothing);

        await tester.tap(find.text('Store now'));
        await settle(tester);

        expect(
          find.text('store refused: Not next to the storage place'),
          findsOneWidget,
        );
      });

      testWidgets('is read by a screen reader and in French', (tester) async {
        final handle = tester.ensureSemantics();
        final unit = _field('u-1', 5);
        await pump(
          tester,
          button(unit),
          snapshot: _snapshot([unit]),
          locale: const Locale('fr'),
        );

        expect(find.text('Mettre en réserve'), findsOneWidget);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('Mettre soldier en réserve'),
          ),
          matchesSemantics(
            label: 'Mettre soldier en réserve',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });
    });
  });
}
