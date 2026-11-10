import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/mocks.dart';

const _snapshot = BattleSnapshot(
  units: {'c-1': blueCommander, 'r-1': redSoldier},
  hqs: [
    HqView(
      team: 'blue',
      position: Position(50500, 5500, 3000),
      hp: 1000,
      maxHp: 1000,
    ),
  ],
  relics: [
    RelicView(relicId: 'relic-1', position: Position(20500, 30500, 3000)),
  ],
  team: 'blue',
  sectionId: 's-blue',
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group(BattleCubit, () {
    late MockBattleRepository repository;
    late StreamController<ConnectionStatus> connection;
    late StreamController<BattleSnapshot> snapshots;
    late BattleCubit cubit;

    setUp(() {
      repository = MockBattleRepository();
      connection = StreamController<ConnectionStatus>.broadcast(sync: true);
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      when(repository.signIn).thenAnswer((_) async {});
      when(() => repository.connection).thenAnswer((_) => connection.stream);
      when(() => repository.snapshots).thenAnswer((_) => snapshots.stream);
      when(() => repository.stopReason).thenReturn(null);
      when(repository.start).thenReturn(null);
      when(() => repository.send(any())).thenAnswer((_) async => null);
      when(repository.close).thenAnswer((_) async {});
      cubit = BattleCubit(repository: repository);
    });

    tearDown(() async {
      await cubit.close();
      await connection.close();
      await snapshots.close();
    });

    /// Plays: signed in to the host, with the section's view.
    Future<void> play() async {
      await cubit.start();
      connection.add(ConnectionStatus.connected);
      snapshots.add(_snapshot);
    }

    test('M7.1 starts signed out, nothing shown', () {
      expect(cubit.state, const BattleState());
      expect(cubit.state.status, BattleStatus.signingIn);
    });

    blocTest<BattleCubit, BattleState>(
      'M7.1 signs in, then connects and keeps the section view',
      build: () => cubit,
      act: (cubit) async {
        await cubit.start();
        connection
          ..add(ConnectionStatus.connecting)
          ..add(ConnectionStatus.connected);
        snapshots.add(_snapshot);
      },
      expect: () => [
        const BattleState(status: BattleStatus.connecting),
        const BattleState(status: BattleStatus.playing),
        const BattleState(
          status: BattleStatus.playing,
          units: {'c-1': blueCommander, 'r-1': redSoldier},
          hqs: [
            HqView(
              team: 'blue',
              position: Position(50500, 5500, 3000),
              hp: 1000,
              maxHp: 1000,
            ),
          ],
          relics: [
            RelicView(
              relicId: 'relic-1',
              position: Position(20500, 30500, 3000),
            ),
          ],
          team: 'blue',
          sectionId: 's-blue',
          revision: 1,
        ),
      ],
      verify: (_) {
        verifyInOrder([repository.signIn, repository.start]);
      },
    );

    test('M7.1 fails, and never connects, when the sign-in fails', () async {
      when(repository.signIn).thenThrow(StateError('no account'));

      await cubit.start();

      expect(cubit.state.status, BattleStatus.failed);
      expect(cubit.state.problem, contains('no account'));
      verifyNever(repository.start);
    });

    test('M7.1 shows a lost host, then the host back', () async {
      await play();
      connection.add(ConnectionStatus.lost);
      expect(cubit.state.status, BattleStatus.lost);

      connection.add(ConnectionStatus.connected);
      expect(cubit.state.status, BattleStatus.playing);
    });

    test('M7.1 shows why it stopped', () async {
      await play();
      when(() => repository.stopReason).thenReturn('Goodbye(battleEnded)');

      connection.add(ConnectionStatus.stopped);

      expect(cubit.state.status, BattleStatus.stopped);
      expect(cubit.state.problem, 'Goodbye(battleEnded)');
    });

    test('M7.1 shows no reason for a repository closed', () async {
      await play();

      connection.add(ConnectionStatus.stopped);

      expect(cubit.state.status, BattleStatus.stopped);
      expect(cubit.state.problem, isNull);
    });

    test('M7.1 shows the battle time and the AP between updates', () async {
      when(() => repository.battleTime).thenReturn(const Duration(hours: 1));
      when(() => repository.apNow(any())).thenReturn(30);

      expect(cubit.battleTime, const Duration(hours: 1));
      expect(cubit.apNow(blueCommander), 30);
      verify(() => repository.apNow(blueCommander.private!.ap)).called(1);
      // Another section's unit has no AP to show.
      expect(cubit.apNow(redSoldier), isNull);
    });

    test('M7.1 selects only the units of its section', () async {
      await play();

      cubit.select('c-1');
      expect(cubit.state.selected, blueCommander);
      cubit.select('r-1');
      expect(cubit.state.selectedId, isNull);
      cubit
        ..select('c-1')
        ..select('nobody');
      expect(cubit.state.selectedId, isNull);
    });

    test('M7.1 lists the units of its section, deployed or stored', () async {
      await play();
      snapshots.add(
        const BattleSnapshot(
          units: {
            'r-1': redSoldier,
            's-1': storedSoldier,
            'c-1': blueCommander,
          },
          hqs: [],
          relics: [],
          team: 'blue',
          sectionId: 's-blue',
        ),
      );

      expect(cubit.state.sectionUnits.map((unit) => unit.unitId), [
        'c-1',
        's-1',
      ]);
      cubit.select('s-1');
      expect(cubit.state.selectedId, 's-1');
    });

    test(
      'decision 3 moves the selected unit and shows the host answer',
      () async {
        await play();
        const to = Position(52000, 9000, 3100);

        // Nothing is selected: nothing goes out.
        await cubit.moveSelectedTo(to);
        verifyNever(() => repository.send(any()));

        cubit.select('c-1');
        await cubit.moveSelectedTo(to);
        verify(() => repository.send(const Move(unitId: 'c-1', to: to)))
            .called(1);
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'move', unitId: 'c-1'),
        );
        expect(cubit.state.notice!.accepted, isTrue);

        when(() => repository.send(any()))
            .thenAnswer((_) async => 'not_enough_ap');
        await cubit.moveSelectedTo(to);
        expect(cubit.state.notice!.refusal, 'not_enough_ap');
        expect(cubit.state.notice!.accepted, isFalse);
      },
    );

    test('M7.1 shows the error of an order that could not go out', () async {
      await play();
      when(() => repository.send(any())).thenThrow(StateError('stopped'));
      cubit.select('c-1');

      await cubit.moveSelectedTo(const Position(0, 0, 0));

      expect(cubit.state.notice!.refusal, contains('stopped'));
    });

    test('M7.1 sends no order while it is not playing', () async {
      await cubit.start();
      connection.add(ConnectionStatus.connecting);
      snapshots.add(_snapshot);
      cubit.select('c-1');

      await cubit.moveSelectedTo(const Position(0, 0, 0));
      await cubit.deploy('c-1');

      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice, isNull);
    });

    test(
      'M7.1 deploys a stored unit of the section, and shows the answer',
      () async {
        await play();

        await cubit.deploy('nobody');
        await cubit.deploy('r-1');
        verifyNever(() => repository.send(any()));

        when(() => repository.send(any()))
            .thenAnswer((_) async => 'not_in_storage');
        await cubit.deploy('c-1');

        verify(() => repository.send(const Deploy(unitId: 'c-1'))).called(1);
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

    test('M7.1 drops the answer of an order once closed', () async {
      await play();
      final answer = Completer<String?>();
      when(() => repository.send(any())).thenAnswer((_) => answer.future);
      cubit.select('c-1');

      final move = cubit.moveSelectedTo(const Position(0, 0, 0));
      await cubit.close();
      answer.complete(null);
      await move;

      expect(cubit.state.notice, isNull);
      verify(repository.close).called(1);
    });
  });

  group('$BattleCubit over a recorded stream', () {
    // What each section got from the start, and what a player who joins
    // the running battle later gets (`_late`).
    for (final name in [
      for (final weather in ['clear', 'fog'])
        for (final section in ['s-1', 's-2'])
          for (final from in ['', '_late']) '${weather}_$section$from',
    ]) {
      test(
        'decision 3 and decision 237 $name ends with the section view the host '
        'holds, no more',
        () async {
          final host = FakeHost.recorded(name);
          final repository = BattleRepository(
            settings: const BattleSettings(
              endpoint: 'http://127.0.0.1:9/v1',
              projectId: 'hawkbee',
              email: 'a@battleteam.local',
              password: 'secret',
              battleId: 'b-1',
            ),
            apiClient: MockAppwriteApiClient()..stubSignIn(),
            transport: host,
            address: (_) async => Uri.parse('ws://host/v1/socket'),
          );
          final cubit = BattleCubit(repository: repository);
          addTearDown(cubit.close);

          await cubit.start();
          await pumpEventQueue(times: 500);

          // What the host holds for that section at the end of its stream.
          final end = FakeHost.recorded('${name.replaceAll('_late', '')}_host');
          expect(cubit.state.status, BattleStatus.playing);
          expect(
            cubit.state.units.keys,
            unorderedEquals([for (final unit in end.view.units) unit.unitId]),
          );
          expect(cubit.state.sectionId, host.sectionId);
          expect(cubit.state.team, host.team);
        },
      );
    }
  });
}

extension on MockAppwriteApiClient {
  void stubSignIn() {
    when(
      () => signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(createJwt).thenAnswer((_) async => 'jwt');
  }
}
