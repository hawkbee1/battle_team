import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:battle_team/shop/widgets/shop_panel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/helpers.dart';
import '../../helpers/shop_cubit.dart';

const _hq = HqView(
  team: 'blue',
  position: Position(50500, 5500, 3000),
  hp: 1000,
  maxHp: 1000,
);

/// A blue unit of [type] on the field next to the HQ.
UnitView _field(String id, {String type = 'soldier'}) => UnitView(
  unitId: id,
  unitType: type,
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: const Position(50600, 5500, 3000),
  weapon: 'rifle',
  private: blueRifleman.private,
);

BattleSnapshot _snapshot(
  List<UnitView> units, {
  int money = 1500,
  Duration? lockedUntil,
  Roster? roster = shopRoster,
}) => BattleSnapshot(
  units: {for (final unit in units) unit.unitId: unit},
  hqs: const [_hq],
  relics: const [],
  section: SectionPrivate(money: money, xp: 0, lockedUntil: lockedUntil),
  roster: roster,
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group(ShopPanel, () {
    late MockBattleRepository repository;
    late StreamController<BattleSnapshot> snapshots;
    late ShopCubit cubit;
    var closed = false;

    setUp(() {
      closed = false;
      repository = MockBattleRepository();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      cubit = shopCubit(snapshots.stream, repository: repository);
    });

    tearDown(() async {
      await cubit.close();
      await snapshots.close();
    });

    /// Shows the panel over [cubit], after the section saw [snapshot], with
    /// [selected] selected.
    Future<void> pump(
      WidgetTester tester, {
      required BattleSnapshot snapshot,
      UnitView? selected,
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
            body: BlocProvider<ShopCubit>.value(
              value: cubit,
              child: SingleChildScrollView(
                child: ShopPanel(
                  selected: selected,
                  onClose: () => closed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    }

    testWidgets('M7.7 waits for the host list before it shows prices', (
      tester,
    ) async {
      await pump(tester, snapshot: _snapshot([blueCommander], roster: null));

      expect(find.text('Waiting for the host’s list…'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
    });

    testWidgets('ECO-04 lists the roster with prices and buys a unit', (
      tester,
    ) async {
      await pump(tester, snapshot: _snapshot([blueCommander]));

      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Money: 1,500 w€'), findsOneWidget);
      expect(find.text('Soldier · 100 w€'), findsOneWidget);
      expect(find.text('Radio · 100 w€'), findsOneWidget);
      expect(find.text('Jeep · 1,500 w€'), findsOneWidget);
      expect(find.text('Buy'), findsNWidgets(3));

      await tester.tap(find.text('Buy').first);
      await settle(tester);

      verify(() => repository.send(const BuyUnit(unitType: 'soldier')))
          .called(1);
      expect(find.text('unit purchase accepted'), findsOneWidget);
    });

    testWidgets('ECO-05 a price above the money is off and says why', (
      tester,
    ) async {
      await pump(tester, snapshot: _snapshot([blueCommander], money: 120));

      expect(find.text('Not enough money'), findsOneWidget);
      final buttons = tester
          .widgetList<TextButton>(find.widgetWithText(TextButton, 'Buy'))
          .toList();
      expect(
        [for (final b in buttons) b.onPressed != null],
        [true, true, false],
      );
    });

    testWidgets('HQ-35 a lock shows its remaining time and turns every '
        'purchase off', (tester) async {
      await pump(
        tester,
        snapshot: _snapshot([
          blueCommander,
        ], lockedUntil: const Duration(hours: 5)),
      );

      expect(
        find.text('Locked for 4.0 h: nothing can be bought'),
        findsOneWidget,
      );
      expect(find.text('The section is locked'), findsNWidgets(3));
      final buttons = tester.widgetList<TextButton>(
        find.widgetWithText(TextButton, 'Buy'),
      );
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });

    testWidgets('HQ-46 no room turns the unit purchases off', (tester) async {
      await pump(
        tester,
        snapshot: _snapshot([
          blueCommander,
          for (var i = 0; i < 4; i++) _field('f-$i'),
        ]),
      );

      expect(find.text('No room for one more unit'), findsNWidgets(3));
    });

    testWidgets('HQ-46 an enemy the section sees near the portal blocks '
        'the arrival', (tester) async {
      await pump(
        tester,
        snapshot: _snapshot([
          blueCommander,
          const UnitView(
            unitId: 'r-1',
            unitType: 'soldier',
            sectionId: 's-red',
            team: 'red',
            hp: 100,
            maxHp: 100,
            position: Position(50600, 5500, 3000),
          ),
        ]),
      );

      expect(find.text('An enemy is near the portal'), findsNWidgets(3));
    });

    testWidgets('the host refusal shows with its reason when the pre-check '
        'missed it', (tester) async {
      when(() => repository.send(any()))
          .thenAnswer((_) async => 'unknown_type');
      await pump(tester, snapshot: _snapshot([blueCommander]));

      await tester.tap(find.text('Buy').first);
      await settle(tester);

      expect(
        find.text('unit purchase refused: Unknown unit type'),
        findsOneWidget,
      );
    });

    testWidgets('UNIT-44 the test unit is listed only where the host lists '
        'it, at 0 w€', (tester) async {
      await pump(tester, snapshot: _snapshot([blueCommander]));
      expect(find.textContaining('Test unit'), findsNothing);

      await pump(
        tester,
        snapshot: _snapshot([blueCommander], roster: shopRosterWithTestUnit),
      );
      expect(find.text('Test unit · 0 w€'), findsOneWidget);
    });

    testWidgets('COMBAT-26 COMBAT-27 a selected own unit shows the weapons '
        'its type uses; buying one sends BuyWeapon', (tester) async {
      await pump(
        tester,
        snapshot: _snapshot([blueCommander, _field('f-1')]),
        selected: _field('f-1'),
      );

      expect(find.text('Weapons for Soldier'), findsOneWidget);
      expect(find.text('A weapon goes to the section’s storage.'), findsOne);
      expect(find.text('Rifle · 100 w€'), findsOneWidget);
      expect(find.text('Machine gun · 150 w€'), findsOneWidget);
      expect(find.text('Anti-tank · 400 w€'), findsOneWidget);
      expect(find.text('Anti-air · 300 w€'), findsOneWidget);

      await tester.tap(find.text('Buy').at(4));
      await settle(tester);

      verify(() => repository.send(const BuyWeapon(weapon: 'machine_gun')))
          .called(1);
      expect(find.text('weapon purchase accepted'), findsOneWidget);
    });

    testWidgets('COMBAT-27 a weapon above the money is off', (tester) async {
      await pump(
        tester,
        snapshot: _snapshot([blueCommander, _field('f-1')], money: 200),
        selected: _field('f-1'),
      );

      // The jeep, and the anti-tank and anti-air weapons.
      expect(find.text('Not enough money'), findsNWidgets(3));
    });

    testWidgets('a unit that uses no weapon, and no selection, say so', (
      tester,
    ) async {
      await pump(
        tester,
        snapshot: _snapshot([blueCommander, _field('f-1', type: 'radio')]),
        selected: _field('f-1', type: 'radio'),
      );
      expect(find.text('Weapons for Radio'), findsOneWidget);
      expect(find.text('This unit uses no weapon.'), findsOneWidget);

      await pump(tester, snapshot: _snapshot([blueCommander]));
      expect(find.text('Weapons'), findsOneWidget);
      expect(
        find.text('Select one of your units to see the weapons it can use.'),
        findsOneWidget,
      );
    });

    testWidgets('decision 237 HQ-29 an enemy selected shows no weapons: the '
        'shop is about the section own units', (tester) async {
      const red = UnitView(
        unitId: 'r-1',
        unitType: 'soldier',
        sectionId: 's-red',
        team: 'red',
        hp: 100,
        maxHp: 100,
        position: Position(60000, 5500, 3000),
      );
      await pump(
        tester,
        snapshot: _snapshot([blueCommander, red]),
        selected: red,
      );

      expect(find.text('Weapons'), findsOneWidget);
      expect(find.textContaining('Rifle'), findsNothing);
    });

    testWidgets('Close closes the panel', (tester) async {
      await pump(tester, snapshot: _snapshot([blueCommander]));

      await tester.tap(find.text('Close'));

      expect(closed, isTrue);
    });

    testWidgets('is read by a screen reader: headers and labelled buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, snapshot: _snapshot([blueCommander], money: 120));

      expect(
        tester.getSemantics(find.text('Shop')),
        matchesSemantics(label: 'Shop', isHeader: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Buy Soldier for 100 w€')),
        matchesSemantics(
          label: 'Buy Soldier for 100 w€',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Buy Jeep for 1,500 w€')),
        matchesSemantics(
          label: 'Buy Jeep for 1,500 w€',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('is in French, prices in the French number format', (
      tester,
    ) async {
      await pump(
        tester,
        snapshot: _snapshot(
          [blueCommander, _field('f-1')],
          money: 120,
          lockedUntil: const Duration(hours: 5),
        ),
        selected: _field('f-1'),
        locale: const Locale('fr'),
      );
      final thousand = NumberFormat.decimalPattern('fr').format(1500);

      expect(thousand, isNot('1,500'));
      expect(find.text('Boutique'), findsOneWidget);
      expect(find.text('Argent : 120 w€'), findsOneWidget);
      expect(find.text('Jeep · $thousand w€'), findsOneWidget);
      expect(find.text('Soldat · 100 w€'), findsOneWidget);
      expect(find.text('Armes pour Soldat'), findsOneWidget);
      expect(find.text('Mitrailleuse · 150 w€'), findsOneWidget);
      expect(
        find.text('Verrouillée pour 4.0 h : rien ne peut être acheté'),
        findsOneWidget,
      );
      expect(find.text('Acheter'), findsWidgets);
    });
  });
}
