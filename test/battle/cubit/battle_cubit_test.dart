import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_host.dart';

void main() {
  group(BattleCubit, () {
    late FakeHost host;
    late BattleCubit cubit;
    var signedIn = 0;

    BattleCubit cubitOf(
      BattleClient client, {
      Future<void> Function()? signIn,
    }) => BattleCubit(client: client, signIn: signIn ?? () async => signedIn++);

    Future<BattleState> until(bool Function(BattleState) test) async {
      if (test(cubit.state)) return cubit.state;
      return await cubit.stream
          .firstWhere(test)
          .timeout(const Duration(seconds: 5));
    }

    setUp(() {
      signedIn = 0;
      host = FakeHost();
      cubit = cubitOf(fakeClient(host));
    });

    tearDown(() => cubit.close());

    test('signs in, then plays with the section view', () async {
      expect(cubit.state.status, BattleStatus.signingIn);

      await cubit.start();
      final state = await until(
        (state) =>
            state.status == BattleStatus.playing && state.units.isNotEmpty,
      );

      expect(signedIn, 1);
      expect(state.team, 'blue');
      expect(state.sectionId, 's-blue');
      expect(state.units.keys, unorderedEquals(['c-1', 'r-1']));
      expect(state.hqs.single.team, 'blue');
      expect(state.relics.single.relicId, 'relic-1');
      expect(cubit.battleTime, isNotNull);
      expect(cubit.apNow(blueCommander), closeTo(30, 1e-9));
      expect(cubit.apNow(redSoldier), isNull);
    });

    test('fails when the sign-in to Appwrite fails', () async {
      cubit = cubitOf(
        fakeClient(host),
        signIn: () async => throw StateError('no account'),
      );

      await cubit.start();

      expect(cubit.state.status, BattleStatus.failed);
      expect(cubit.state.problem, contains('no account'));
    });

    test('selects only the units of its section', () async {
      await cubit.start();
      await until((state) => state.units.isNotEmpty);

      cubit.select('c-1');
      expect(cubit.state.selected, blueCommander);
      cubit.select('r-1');
      expect(cubit.state.selectedId, isNull);
      cubit
        ..select('c-1')
        ..select('nobody');
      expect(cubit.state.selectedId, isNull);
    });

    test('moves the selected unit and shows the answer', () async {
      await cubit.start();
      await until((state) => state.units.isNotEmpty);
      const to = Position(52000, 9000, 3100);

      await cubit.moveSelectedTo(to);
      expect(host.orders, isEmpty);

      cubit.select('c-1');
      await cubit.moveSelectedTo(to);
      expect(host.orders.single, const Move(unitId: 'c-1', to: to));
      expect(
        cubit.state.notice,
        const OrderNotice(order: 'move', unitId: 'c-1'),
      );
      expect(cubit.state.notice!.accepted, isTrue);

      host.refusal = 'not_enough_ap';
      await cubit.moveSelectedTo(to);
      expect(cubit.state.notice!.refusal, 'not_enough_ap');
      expect(cubit.state.notice!.accepted, isFalse);
    });

    test(
      'deploys a stored unit of the section, and shows the answer',
      () async {
        await cubit.start();
        await until((state) => state.units.isNotEmpty);

        await cubit.deploy('nobody');
        await cubit.deploy('r-1');
        expect(host.orders, isEmpty);

        host.refusal = 'not_in_storage';
        await cubit.deploy('c-1');

        expect(host.orders.single, const Deploy(unitId: 'c-1'));
        expect(
          cubit.state.notice,
          const OrderNotice(
            order: 'deploy',
            unitId: 'c-1',
            refusal: 'not_in_storage',
          ),
        );
      },
    );

    test('lists the units of its section, deployed or stored', () async {
      host = FakeHost(
        view: const SectionView(
          at: Duration(hours: 1),
          section: SectionPrivate(money: 0, xp: 0),
          units: [blueCommander, storedSoldier, redSoldier],
          hqs: [],
          relics: [],
          world: [],
        ),
      );
      cubit = cubitOf(fakeClient(host));
      await cubit.start();
      await until((state) => state.units.length == 3);

      expect(cubit.state.sectionUnits.map((unit) => unit.unitId), [
        'c-1',
        's-1',
      ]);
      cubit.select('s-1');
      expect(cubit.state.selectedId, 's-1');
      cubit.select('r-1');
      expect(cubit.state.selectedId, isNull);
    });

    test('shows why it stopped', () async {
      await cubit.start();
      await until((state) => state.status == BattleStatus.playing);

      host.sockets.last.deliver(const Goodbye(GoodbyeReason.battleEnded));
      final state = await until(
        (state) => state.status == BattleStatus.stopped,
      );

      expect(state.problem, contains('battleEnded'));
    });

    test('shows a lasting refusal of the host address', () async {
      cubit = cubitOf(
        fakeClient(
          host,
          address: (_) async =>
              throw const HostLookupException('not_your_battle', status: 403),
        ),
      );

      await cubit.start();
      final state = await until(
        (state) => state.status == BattleStatus.stopped,
      );

      expect(state.problem, 'not_your_battle');
    });

    test('shows a lost host, and no reason for a client closed', () async {
      cubit = cubitOf(
        fakeClient(host, address: (_) async => throw StateError('down')),
      );

      await cubit.start();
      await until((state) => state.status == BattleStatus.lost);
      await cubit.client.close();
      final state = await until(
        (state) => state.status == BattleStatus.stopped,
      );

      expect(state.problem, isNull);
    });

    test('drops the answer of a move once closed', () async {
      await cubit.start();
      await until((state) => state.units.isNotEmpty);
      host.silent = true;
      cubit.select('c-1');

      final move = cubit.moveSelectedTo(const Position(0, 0, 0));
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      await move;

      expect(cubit.state.notice, isNull);
    });
  });

  group(BattleState, () {
    test('clears the selection and the notice', () {
      const state = BattleState(
        selectedId: 'c-1',
        notice: OrderNotice(order: 'move', unitId: 'c-1'),
      );

      final cleared = state.copyWith(
        selectedId: () => null,
        notice: () => null,
      );

      expect(cleared.selectedId, isNull);
      expect(cleared.notice, isNull);
      expect(state.copyWith(), state);
    });
  });
}
