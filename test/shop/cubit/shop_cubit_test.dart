import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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

/// A red soldier [metres] metres east of the HQ.
UnitView _red(String id, double metres) => UnitView(
  unitId: id,
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position(50500 + (metres * 100).round(), 5500, 3000),
);

/// A blue soldier of the section on the field.
UnitView _field(String id) => UnitView(
  unitId: id,
  unitType: 'soldier',
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
  int money = 500,
  Duration? lockedUntil,
  Roster? roster = shopRoster,
  List<HqView> hqs = const [_hq],
}) => BattleSnapshot(
  units: {for (final unit in units) unit.unitId: unit},
  hqs: hqs,
  relics: const [],
  section: SectionPrivate(money: money, xp: 0, lockedUntil: lockedUntil),
  roster: roster,
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group(ShopCubit, () {
    late MockBattleRepository repository;
    late StreamController<BattleSnapshot> snapshots;
    late ShopCubit cubit;
    late LogCapture log;

    setUp(() {
      repository = MockBattleRepository();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      cubit = shopCubit(snapshots.stream, repository: repository);
      log = LogCapture();
    });

    tearDown(() async {
      await log.cancel();
      await cubit.close();
      await snapshots.close();
    });

    void see(
      List<UnitView> units, {
      int money = 500,
      Duration? lockedUntil,
      Roster? roster = shopRoster,
      List<HqView> hqs = const [_hq],
    }) => snapshots.add(
      _snapshot(
        units,
        money: money,
        lockedUntil: lockedUntil,
        roster: roster,
        hqs: hqs,
      ),
    );

    RosterUnit soldier() => shopRoster.units.first;

    test('M7.7 follows the section view: roster, money, portal', () {
      expect(cubit.state.roster, isNull);

      see([blueCommander]);

      expect(cubit.state.roster, shopRoster);
      expect(cubit.state.section!.money, 500);
      expect(cubit.state.portal, _hq.position);
      expect(cubit.state.team, 'blue');
      expect(cubit.state.revision, 1);
    });

    test('M7.7 the portal is its own team HQ, not an enemy one', () {
      see(
        [blueCommander],
        hqs: const [
          HqView(team: 'red', position: Position(1, 1, 1), hp: 1, maxHp: 1),
        ],
      );
      expect(cubit.state.portal, isNull);

      see([blueCommander]);
      expect(cubit.state.portal, _hq.position);
    });

    test('M7.7 the money updates from the next private state', () {
      see([blueCommander]);
      see([blueCommander], money: 400);

      expect(cubit.state.section!.money, 400);
    });

    test('HQ-29 the shop holds the section own units and money only', () {
      const other = UnitView(
        unitId: 'x-1',
        unitType: 'soldier',
        sectionId: 's-green',
        team: 'blue',
        hp: 100,
        maxHp: 100,
      );
      see([blueCommander, other, _red('r-1', 500)]);

      expect(cubit.state.ownUnits, [blueCommander]);
    });

    test('ECO-04 buying a unit sends BuyUnit and shows the answer', () async {
      see([blueCommander]);

      await cubit.buyUnit('soldier');

      verify(() => repository.send(const BuyUnit(unitType: 'soldier')))
          .called(1);
      expect(
        cubit.state.notice,
        const PurchaseNotice(order: 'buy_unit', item: 'soldier'),
      );
      expect(log.records.map((r) => r.message), [
        'order buy_unit sent',
        'order buy_unit accepted',
      ]);
    });

    test('ECO-05 a radio is bought the same way', () async {
      see([blueCommander]);

      await cubit.buyUnit('radio');

      verify(() => repository.send(const BuyUnit(unitType: 'radio'))).called(1);
    });

    test('ECO-05 not enough money is refused with the reason, nothing '
        'sent', () async {
      see([blueCommander], money: 99);

      expect(
        cubit.checkUnit(soldier()),
        const PreCheckRefused(PreCheckRefusal.notEnoughMoney),
      );
      await cubit.buyUnit('soldier');

      verifyNever(() => repository.send(any()));
      expect(
        cubit.state.notice,
        const PurchaseNotice(
          order: 'buy_unit',
          item: 'soldier',
          refusal: 'not_enough_money',
        ),
      );
      expect(log.records.last.level, Level.WARNING);
      expect(
        log.records.last.message,
        'order buy_unit not sent: not_enough_money',
      );
    });

    test(
      'HQ-35 HQ-46 a locked section buys nothing and shows the lock',
      () async {
        see([blueCommander], lockedUntil: const Duration(hours: 25));

        expect(cubit.lockRemaining, const Duration(hours: 24));
        expect(
          cubit.checkUnit(soldier()),
          const PreCheckRefused(PreCheckRefusal.sectionLocked),
        );
        await cubit.buyUnit('soldier');
        verifyNever(() => repository.send(any()));
        expect(cubit.state.notice!.refusal, 'section_locked');
      },
    );

    test('HQ-35 the lock is over when the battle time reaches its end', () {
      see([blueCommander], lockedUntil: const Duration(hours: 1));

      expect(cubit.lockRemaining, isNull);
      expect(cubit.checkUnit(soldier()), const PreCheckPassed());
    });

    test('HQ-36 HQ-46 an enemy the section sees within 20 m of the portal '
        'blocks a purchase', () async {
      see([blueCommander, _red('r-1', 10)]);

      expect(
        cubit.checkUnit(soldier()),
        const PreCheckRefused(PreCheckRefusal.arrivalBlocked),
      );
      await cubit.buyUnit('soldier');
      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice!.refusal, 'arrival_blocked');
    });

    test('decision 237 an enemy the section does not see gives no clue: the '
        'order is sent and the host refusal shows', () async {
      see([blueCommander]);
      when(() => repository.send(any()))
          .thenAnswer((_) async => 'arrival_blocked');

      await cubit.buyUnit('soldier');

      verify(() => repository.send(const BuyUnit(unitType: 'soldier')))
          .called(1);
      expect(cubit.state.notice!.refusal, 'arrival_blocked');
      expect(
        log.records.last.message,
        'order buy_unit refused arrival_blocked',
      );
      for (final text in log.texts) {
        expect(text, isNot(contains('r-1')));
      }
    });

    test('ECO-04 UNIT-39 a section with no room buys no unit', () async {
      see([blueCommander, for (var i = 0; i < 4; i++) _field('f-$i')]);

      expect(
        cubit.checkUnit(soldier()),
        const PreCheckRefused(PreCheckRefusal.noRoom),
      );
      await cubit.buyUnit('soldier');
      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice!.refusal, 'no_room');
    });

    test(
      'COMBAT-27 buying a weapon sends BuyWeapon and needs no room',
      () async {
        see([blueCommander, for (var i = 0; i < 4; i++) _field('f-$i')]);

        await cubit.buyWeapon('machine_gun');

        verify(() => repository.send(const BuyWeapon(weapon: 'machine_gun')))
            .called(1);
        expect(
          cubit.state.notice,
          const PurchaseNotice(order: 'buy_weapon', item: 'machine_gun'),
        );
      },
    );

    test(
      'COMBAT-27 a weapon above the money is refused, nothing sent',
      () async {
        see([blueCommander], money: 399);

        expect(
          cubit.checkWeapon(shopRoster.weapons[2]),
          const PreCheckRefused(PreCheckRefusal.notEnoughMoney),
        );
        await cubit.buyWeapon('anti_tank');

        verifyNever(() => repository.send(any()));
        expect(cubit.state.notice!.refusal, 'not_enough_money');
      },
    );

    test('M7.7 something not on the roster is never sent', () async {
      see([blueCommander]);

      await cubit.buyUnit('tank');
      await cubit.buyWeapon('artillery');

      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice, isNull);
    });

    test('M7.7 before the host sent its view nothing is expected refused: '
        'the host decides', () {
      expect(cubit.checkUnit(soldier()), const PreCheckPassed());
      expect(
        cubit.checkWeapon(shopRoster.weapons.first),
        const PreCheckPassed(),
      );
      expect(cubit.lockRemaining, isNull);
    });

    test('M7.7 an order that cannot go out shows its error and is logged '
        'severe', () async {
      see([blueCommander]);
      when(() => repository.send(any())).thenThrow(StateError('closed'));

      await cubit.buyUnit('soldier');

      expect(cubit.state.notice!.refusal, contains('closed'));
      expect(log.records.last.level, Level.SEVERE);
      expect(log.records.last.message, 'order buy_unit failed');
    });

    test(
      'M7.7 an answer that comes after the cubit closed changes nothing',
      () async {
        see([blueCommander]);
        final answer = Completer<String?>();
        when(() => repository.send(any())).thenAnswer((_) => answer.future);

        final bought = cubit.buyUnit('soldier');
        await cubit.close();
        answer.complete(null);
        await bought;

        expect(cubit.state.notice, isNull);
      },
    );
  });
}
