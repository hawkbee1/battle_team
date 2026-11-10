import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/log_capture.dart';
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

    group('logs', () {
      late LogCapture log;

      setUp(() => log = LogCapture());

      tearDown(() => log.cancel());

      test('M7.3 the sign-in, the connection and an accepted order', () async {
        await play();
        cubit.select('c-1');
        await cubit.moveSelectedTo(const Position(52000, 9000, 3100));

        expect(
          log.lines,
          equals([
            'INFO signing in',
            'INFO signed in',
            'INFO connection connected',
            'INFO order move sent',
            'INFO order move accepted',
          ]),
        );
        expect(
          log.records.map((record) => record.loggerName).toSet(),
          equals({'battle_team.BattleCubit'}),
        );
      });

      test('M7.3 a refused order as a WARNING with its code', () async {
        await play();
        when(() => repository.send(any()))
            .thenAnswer((_) async => 'not_enough_ap');
        cubit.select('c-1');

        await cubit.moveSelectedTo(const Position(0, 0, 0));

        expect(
          log.records.last,
          isA<LogRecord>()
              .having((record) => record.level, 'level', Level.WARNING)
              .having(
                (record) => record.message,
                'message',
                'order move refused not_enough_ap',
              ),
        );
      });

      test('M7.3 an order that could not go out as SEVERE', () async {
        await play();
        when(() => repository.send(any())).thenThrow(StateError('stopped'));
        cubit.select('c-1');

        await cubit.deploy('c-1');

        final failed = log.records.last;
        expect(failed.level, Level.SEVERE);
        expect(failed.message, 'order deploy failed');
        expect(failed.error, isA<StateError>());
        expect(failed.stackTrace, isNotNull);
      });

      test('M7.3 a sign-in that failed as SEVERE', () async {
        when(repository.signIn).thenThrow(StateError('no account'));

        await cubit.start();

        final failed = log.records.last;
        expect(failed.level, Level.SEVERE);
        expect(failed.message, 'sign-in failed');
        expect(failed.error, isA<StateError>());
      });

      test('decision 237 names no unit and no position of the state', () async {
        await play();
        cubit.select('c-1');
        await cubit.moveSelectedTo(const Position(52000, 9000, 3100));

        for (final text in log.texts) {
          expect(text, isNot(contains('c-1')));
          expect(text, isNot(contains('r-1')));
          expect(text, isNot(contains('52000')));
        }
      });
    });

    group('view from a unit', () {
      /// The blue commander as a later update shows it.
      UnitView commanderWith({
        double hp = 200,
        UnitPlace place = UnitPlace.deployed,
        bool onMap = true,
        Position at = const Position(50900, 5900, 3000),
      }) => UnitView(
        unitId: 'c-1',
        unitType: 'commander',
        sectionId: 's-blue',
        team: 'blue',
        hp: hp,
        maxHp: 200,
        position: onMap ? at : null,
        private: UnitPrivate(
          place: place,
          ap: blueCommander.private!.ap,
          morale: 100,
          rounds: 10,
          xpEarned: 0,
          xpUnspent: 0,
        ),
      );

      BattleSnapshot withCommander(UnitView? commander) => BattleSnapshot(
        units: {'c-1': ?commander, 'r-1': redSoldier},
        hqs: _snapshot.hqs,
        relics: _snapshot.relics,
        team: 'blue',
        sectionId: 's-blue',
      );

      blocTest<BattleCubit, BattleState>(
        'decision 5 first person enters from an own unit and leaves to '
        'top-down',
        build: () => cubit,
        act: (cubit) async {
          await play();
          cubit
            ..select('c-1')
            ..enterFirstPerson()
            ..leaveFirstPerson();
        },
        skip: 2,
        expect: () => [
          isA<BattleState>().having(
            (state) => state.selectedId,
            'selected',
            'c-1',
          ),
          isA<BattleState>()
              .having(
                (state) => state.viewMode,
                'mode',
                const FirstPersonMode('c-1'),
              )
              .having((state) => state.seenFrom, 'seen from', blueCommander),
          isA<BattleState>()
              .having((state) => state.viewMode, 'mode', const TopDownMode())
              .having((state) => state.seenFrom, 'seen from', isNull),
        ],
      );

      test('decision 5 starts and stays in top-down until asked', () async {
        await play();

        expect(cubit.state.viewMode, const TopDownMode());
        cubit.leaveFirstPerson();
        expect(cubit.state.viewMode, const TopDownMode());
      });

      test('decision 5 cannot enter first person without a unit of the '
          'section on the field', () async {
        await play();
        cubit.enterFirstPerson();
        expect(cubit.state.viewMode, const TopDownMode());

        // A stored unit is selectable but has no eyes on the field.
        snapshots.add(
          BattleSnapshot(
            units: const {'s-1': storedSoldier, 'r-1': redSoldier},
            hqs: _snapshot.hqs,
            relics: _snapshot.relics,
            team: 'blue',
            sectionId: 's-blue',
          ),
        );
        cubit
          ..select('s-1')
          ..enterFirstPerson();
        expect(cubit.state.selectedId, 's-1');
        expect(cubit.state.viewMode, const TopDownMode());
      });

      for (final (name, commander) in [
        ('is stored', commanderWith(place: UnitPlace.stored, onMap: false)),
        ('is carried', commanderWith(place: UnitPlace.carried)),
        ('dies', commanderWith(hp: 0)),
        ('has no place on the map', commanderWith(onMap: false)),
        ('leaves the section sight', null),
      ]) {
        test('decision 5 first person ends when the unit $name', () async {
          await play();
          cubit
            ..select('c-1')
            ..enterFirstPerson();
          expect(cubit.state.viewMode, const FirstPersonMode('c-1'));

          snapshots.add(withCommander(commander));

          expect(cubit.state.viewMode, const TopDownMode());
        });
      }

      test('decision 5 first person goes on while the unit moves and fights, '
          'and the view follows it', () async {
        await play();
        cubit
          ..select('c-1')
          ..enterFirstPerson();

        snapshots.add(withCommander(commanderWith(hp: 120)));

        expect(cubit.state.viewMode, const FirstPersonMode('c-1'));
        expect(cubit.state.seenFrom?.hp, 120);
        expect(
          cubit.state.seenFrom?.position,
          const Position(50900, 5900, 3000),
        );
      });

      test('decision 5 first person ends when another unit is selected or '
          'the selection clears, and goes on for the same unit', () async {
        await play();
        snapshots.add(
          BattleSnapshot(
            units: const {
              'c-1': blueCommander,
              's-1': storedSoldier,
              'r-1': redSoldier,
            },
            hqs: _snapshot.hqs,
            relics: _snapshot.relics,
            team: 'blue',
            sectionId: 's-blue',
          ),
        );
        cubit
          ..select('c-1')
          ..enterFirstPerson()
          ..select('c-1');
        expect(cubit.state.viewMode, const FirstPersonMode('c-1'));

        cubit.select('s-1');
        expect(cubit.state.viewMode, const TopDownMode());
        expect(cubit.state.selectedId, 's-1');

        cubit
          ..select('c-1')
          ..enterFirstPerson()
          ..select(null);
        expect(cubit.state.viewMode, const TopDownMode());
        expect(cubit.state.selectedId, isNull);
      });

      test('decision 5 a move order from first person is the same Move '
          'order', () async {
        await play();
        cubit
          ..select('c-1')
          ..enterFirstPerson();

        await cubit.moveSelectedTo(const Position(52000, 9000, 3100));

        verify(
          () => repository.send(
            const Move(unitId: 'c-1', to: Position(52000, 9000, 3100)),
          ),
        ).called(1);
        expect(cubit.state.viewMode, const FirstPersonMode('c-1'));
        expect(cubit.state.notice?.accepted, isTrue);
      });

      group('logs', () {
        late LogCapture log;

        setUp(() => log = LogCapture());

        tearDown(() => log.cancel());

        test('M7.4 enters, leaves and ends, and names no unit', () async {
          await play();
          log.records.clear();
          cubit
            ..select('c-1')
            ..enterFirstPerson()
            ..leaveFirstPerson()
            ..enterFirstPerson()
            ..select(null)
            ..select('c-1')
            ..enterFirstPerson();
          snapshots.add(withCommander(null));

          expect(
            log.lines,
            equals([
              'INFO first person entered',
              'INFO first person left',
              'INFO first person entered',
              'INFO first person ended: the selection changed',
              'INFO first person entered',
              'INFO first person ended: the unit is gone',
            ]),
          );
          for (final text in log.texts) {
            expect(text, isNot(contains('c-1')));
          }
        });
      });
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
