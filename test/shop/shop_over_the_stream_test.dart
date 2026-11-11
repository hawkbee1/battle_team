import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/shop/cubit/shop_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_host.dart';
import '../helpers/real_cubit.dart';

/// Plays [host] through the real cubit, repository, client and codec, and
/// gives the shop cubit that followed the view.
Future<({BattleCubit battle, ShopCubit shop})> play(FakeHost host) async {
  final battle = realCubit(host);
  final shop = ShopCubit(
    repository: battle.repository,
    preCheck: battle.preCheck,
  )..start();
  addTearDown(shop.close);
  addTearDown(battle.close);
  await battle.start();
  await pumpEventQueue(times: 500);
  return (battle: battle, shop: shop);
}

void main() {
  group('the shop over the host streams', () {
    test('ECO-04 UNIT-44 a recorded stream: the roster is the host one, '
        'priced from the plan, and the shop buys from it', () async {
      for (final name in ['clear_s-1', 'clear_s-2', 'fog_s-1', 'fog_s-2']) {
        final host = FakeHost.recorded(name);
        final (battle: _, :shop) = await play(host);

        final roster = shop.state.roster!;
        expect(roster.units.map((u) => u.unitType), contains('soldier'));
        expect(
          roster.units.map((u) => u.unitType),
          isNot(contains('test_unit')),
        );
        expect(shop.state.section, isNotNull);
        expect(shop.state.sectionId, host.sectionId);

        await shop.buyWeapon('rifle');
        expect(host.orders, [const BuyWeapon(weapon: 'rifle')], reason: name);
      }
    });

    test('ECO-04 a roster the host sends after its view is bought from, '
        'through the codec, and the host answer shows', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: const SectionPrivate(money: 500, xp: 0),
          units: const [blueCommander],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
        roster: shopRoster,
      );
      final (battle: _, :shop) = await play(host);

      expect(shop.state.roster, shopRoster);
      await shop.buyUnit('soldier');

      expect(host.orders, [const BuyUnit(unitType: 'soldier')]);
      expect(shop.state.notice!.refusal, isNull);
    });

    test('decision 237 an enemy the section does not see: the order goes '
        'out and the host refusal shows as the host one', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: const SectionPrivate(money: 500, xp: 0),
          units: const [blueCommander],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
        roster: shopRoster,
      )..refusal = 'arrival_blocked';
      final (battle: _, :shop) = await play(host);

      expect(shop.checkUnit(shopRoster.units.first), const PreCheckPassed());
      await shop.buyUnit('soldier');

      expect(host.orders, [const BuyUnit(unitType: 'soldier')]);
      expect(shop.state.notice!.refusal, 'arrival_blocked');
    });

    test('ECO-05 money the host sends later is the money the shop checks '
        'against', () async {
      final host = FakeHost(
        view: SectionView(
          weather: 'clear',
          at: blueView.at,
          section: const SectionPrivate(money: 50, xp: 0),
          units: const [blueCommander],
          hqs: blueView.hqs,
          relics: blueView.relics,
          world: blueView.world,
        ),
        roster: shopRoster,
        updates: [
          TickUpdate(
            at: blueView.at + const Duration(minutes: 1),
            section: const SectionPrivate(money: 250, xp: 0),
          ),
        ],
      );
      final (battle: _, :shop) = await play(host);

      expect(shop.state.section!.money, 250);
      await shop.buyUnit('soldier');
      expect(host.orders, [const BuyUnit(unitType: 'soldier')]);
    });
  });
}
