import 'dart:async';

import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/mocks.dart';
import '../../helpers/pre_check.dart';

const _hq = HqView(
  team: 'blue',
  position: Position(50500, 5500, 3000),
  hp: 1000,
  maxHp: 1000,
);

BattleSnapshot _snapshot({required bool managesHq}) => BattleSnapshot(
  units: const {'c-1': blueCommander, 'g-1': blueGun, 'r-1': redSoldier},
  hqs: const [
    _hq,
    HqView(
      team: 'red',
      position: Position(90500, 5500, 3000),
      hp: 1000,
      maxHp: 1000,
    ),
  ],
  relics: const [],
  team: 'blue',
  sectionId: 's-blue',
  managesHq: managesHq,
);

void main() {
  setUpAll(registerBattleFallbackValues);

  group('$BattleCubit and the HQ', () {
    late MockBattleRepository repository;
    late StreamController<ConnectionStatus> connection;
    late StreamController<BattleSnapshot> snapshots;
    late BattleCubit cubit;

    setUp(() {
      repository = MockBattleRepository();
      connection = StreamController<ConnectionStatus>.broadcast(sync: true);
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      when(() => repository.connection).thenAnswer((_) => connection.stream);
      when(() => repository.snapshots).thenAnswer((_) => snapshots.stream);
      when(() => repository.stopReason).thenReturn(null);
      when(repository.start).thenReturn(null);
      when(() => repository.send(any())).thenAnswer((_) async => null);
      when(repository.close).thenAnswer((_) async {});
      when(() => repository.battleTime).thenReturn(const Duration(hours: 1));
      when(
        () => repository.apNow(any()),
      ).thenAnswer((call) => (call.positionalArguments.first as ApView).value);
      cubit = BattleCubit(repository: repository, preCheck: testPreCheck());
    });

    tearDown(() async {
      await cubit.close();
      await connection.close();
      await snapshots.close();
    });

    void play({required bool managesHq}) {
      cubit.start();
      connection.add(ConnectionStatus.connected);
      snapshots.add(_snapshot(managesHq: managesHq));
    }

    test('HQ-05 knows the HQ of its own team, and whether it manages it', () {
      play(managesHq: true);

      expect(cubit.state.ownHq, _hq);
      expect(cubit.state.managesHq, isTrue);
      expect(const BattleState().ownHq, isNull);
    });

    test('HQ-10 the manager arms a move of the HQ, and the next tap on the '
        'ground sends it', () async {
      play(managesHq: true);
      const to = Position(60500, 7500, 3000);

      cubit.toggleHqMove();
      expect(cubit.state.hqMove, isTrue);
      await cubit.moveHqTo(to);

      verify(() => repository.send(const MoveHq(to: to))).called(1);
      expect(cubit.state.hqMove, isFalse);
      expect(
        cubit.state.notice,
        const OrderNotice(order: 'move_hq', unitId: 'hq'),
      );
    });

    test('HQ-10 the manager disarms the move by pressing again', () {
      play(managesHq: true);

      cubit
        ..toggleHqMove()
        ..toggleHqMove();

      expect(cubit.state.hqMove, isFalse);
    });

    test('HQ-10 a player who does not manage the HQ arms nothing and sends '
        'nothing', () async {
      play(managesHq: false);

      cubit.toggleHqMove();
      await cubit.moveHqTo(const Position(60500, 7500, 3000));

      expect(cubit.state.hqMove, isFalse);
      verifyNever(() => repository.send(any()));
    });

    test('HQ-10 selecting a unit or arming a shot gives up the move of the '
        'HQ', () {
      play(managesHq: true);

      cubit
        ..toggleHqMove()
        ..select('g-1');
      expect(cubit.state.hqMove, isFalse);

      cubit
        ..toggleHqMove()
        ..toggleGroundFire();
      expect(cubit.state.groundFire, isTrue);
      expect(cubit.state.hqMove, isFalse);

      cubit.toggleHqMove();
      expect(cubit.state.hqMove, isTrue);
      expect(cubit.state.groundFire, isFalse);
    });

    test('HQ-05 loses the armed move when the role goes to someone else', () {
      play(managesHq: true);
      cubit.toggleHqMove();

      snapshots.add(_snapshot(managesHq: false));

      expect(cubit.state.managesHq, isFalse);
      expect(cubit.state.hqMove, isFalse);
    });

    test('HQ-14 the AP of the HQ come from the repository for its pool', () {
      const ap = ApView(value: 10, at: Duration.zero, perHour: 1, max: 30);
      when(() => repository.apNow(ap)).thenReturn(12.5);

      expect(cubit.hqApNow(ap), 12.5);
    });
  });
}
