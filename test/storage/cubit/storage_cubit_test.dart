import 'dart:async';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/storage/cubit/storage_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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

/// A blue rifleman in the field at [metresEast] metres east of the HQ.
UnitView _field(String id, {double metresEast = 5}) => UnitView(
  unitId: id,
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: Position(50500 + (metresEast * 100).round(), 5500, 3000),
  weapon: 'rifle',
  private: blueRifleman.private,
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

  group(StorageCubit, () {
    late MockBattleRepository repository;
    late StreamController<BattleSnapshot> snapshots;
    late StorageCubit cubit;
    late LogCapture log;

    setUp(() {
      repository = MockBattleRepository();
      snapshots = StreamController<BattleSnapshot>.broadcast(sync: true);
      cubit = storageCubit(snapshots.stream, repository: repository);
      log = LogCapture();
    });

    tearDown(() async {
      await log.cancel();
      await cubit.close();
      await snapshots.close();
    });

    /// The section sees [units] next to its HQ.
    void see(
      List<UnitView> units, {
      SectionPrivate section = const SectionPrivate(money: 0, xp: 0),
      Map<String, Duration> recalls = const {},
      List<HqView> hqs = const [_hq],
    }) => snapshots.add(
      _snapshot(units, section: section, recalls: recalls, hqs: hqs),
    );

    test('M7.6 follows the section view: portal, lock, prisoners', () {
      see(
        [storedSoldier],
        section: const SectionPrivate(
          money: 0,
          xp: 0,
          lockedUntil: Duration(hours: 5),
          prisoners: [JoinedUnit(unitId: 'r-9', unitType: 'soldier')],
        ),
        recalls: {'u-1': const Duration(hours: 7)},
      );

      expect(cubit.state.sectionId, 's-blue');
      expect(cubit.state.portal, _hq.position);
      expect(cubit.state.lockedUntil, const Duration(hours: 5));
      expect(cubit.state.prisoners, hasLength(1));
      expect(cubit.state.recalls, {'u-1': const Duration(hours: 7)});
      expect(cubit.state.revision, 1);
    });

    test('M7.6 the portal is its own team HQ, not an enemy one', () {
      see(
        [storedSoldier],
        hqs: const [
          HqView(team: 'red', position: Position(1, 1, 1), hp: 1, maxHp: 1),
        ],
      );
      expect(cubit.state.portal, isNull);

      see([storedSoldier]);
      expect(cubit.state.portal, _hq.position);
    });

    test('HQ-29 the storage view shows only the section own stored units', () {
      const otherStored = UnitView(
        unitId: 'x-1',
        unitType: 'soldier',
        sectionId: 's-green',
        team: 'blue',
        hp: 100,
        maxHp: 100,
      );
      see([storedSoldier, blueCommander, otherStored, redSoldier]);

      expect(cubit.state.stored, [storedSoldier]);
      expect(cubit.state.sectionUnits, [blueCommander, storedSoldier]);
    });

    test(
      'HQ-33 deploy sends Deploy for a stored unit and shows its cost',
      () async {
        see([storedSoldier]);

        await cubit.deploy('s-1');

        expect(cubit.deployAp, 10);
        verify(() => repository.send(const Deploy(unitId: 's-1'))).called(1);
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'deploy', unitId: 's-1'),
        );
      },
    );

    test('HQ-33 a unit short of the deploy AP is sent and waits', () async {
      const tired = UnitView(
        unitId: 's-2',
        unitType: 'soldier',
        sectionId: 's-blue',
        team: 'blue',
        hp: 100,
        maxHp: 100,
        private: UnitPrivate(
          sightRangeM: 60,
          place: UnitPlace.stored,
          ap: ApView(value: 4, at: Duration(hours: 1), perHour: 1, max: 30),
          morale: 100,
          rounds: 10,
          xpEarned: 0,
          xpUnspent: 0,
        ),
      );
      see([tired]);

      expect(
        cubit.checkDeploy(tired),
        const PreCheckPassed(apWait: Duration(hours: 6)),
      );
      await cubit.deploy('s-2');
      verify(() => repository.send(const Deploy(unitId: 's-2'))).called(1);
    });

    test('HQ-35 a locked section shows the lock and sends nothing', () async {
      see(
        [storedSoldier],
        section: const SectionPrivate(
          money: 0,
          xp: 0,
          lockedUntil: Duration(hours: 25),
        ),
      );

      expect(cubit.lockRemaining, const Duration(hours: 24));
      expect(
        cubit.checkDeploy(storedSoldier),
        const PreCheckRefused(PreCheckRefusal.sectionLocked),
      );
      await cubit.deploy('s-1');

      verifyNever(() => repository.send(any()));
      expect(
        cubit.state.notice,
        const OrderNotice(
          order: 'deploy',
          unitId: 's-1',
          refusal: 'section_locked',
        ),
      );
      expect(log.records.last.level, Level.WARNING);
      expect(log.records.last.message, 'order deploy not sent: section_locked');
    });

    test('HQ-35 a lock that ended, or none, is no lock', () {
      see(
        [storedSoldier],
        section: const SectionPrivate(
          money: 0,
          xp: 0,
          lockedUntil: Duration(minutes: 30),
        ),
      );
      expect(cubit.lockRemaining, isNull);

      see([storedSoldier]);
      expect(cubit.lockRemaining, isNull);
    });

    test(
      'HQ-36 an enemy within 20 m shows blocked and sends nothing',
      () async {
        see([storedSoldier, _red('r-1', 20)]);

        expect(cubit.blockRadiusM, 20);
        expect(
          cubit.checkDeploy(storedSoldier),
          const PreCheckRefused(PreCheckRefusal.blockedByEnemy),
        );
        await cubit.deploy('s-1');

        verifyNever(() => repository.send(any()));
        expect(cubit.state.notice!.refusal, 'blocked_by_enemy');
      },
    );

    test('decision 237 an enemy the section does not see gives no clue, the '
        "host's refusal shows", () async {
      see([storedSoldier, _red('r-far', 400)]);
      when(() => repository.send(any()))
          .thenAnswer((_) async => 'blocked_by_enemy');

      expect(cubit.checkDeploy(storedSoldier), const PreCheckPassed());
      await cubit.deploy('s-1');

      verify(() => repository.send(const Deploy(unitId: 's-1'))).called(1);
      expect(cubit.state.notice!.refusal, 'blocked_by_enemy');
      expect(log.records.last.message, 'order deploy refused blocked_by_enemy');
    });

    test('HQ-31 a unit next to its portal is stored at once', () async {
      see([_field('u-1')]);

      expect(cubit.planStore(_field('u-1')), const StoredNow());
      await cubit.storeOrRecall('u-1');

      verify(() => repository.send(const Store(unitId: 'u-1'))).called(1);
    });

    test(
      'HQ-32 a unit farther shows the recall delay and is recalled',
      () async {
        final far = _field('u-1', metresEast: 100);
        see([far]);

        expect(cubit.planStore(far), const RecalledAfter(Duration(hours: 6)));
        await cubit.storeOrRecall('u-1');

        verify(() => repository.send(const Recall(unitId: 'u-1'))).called(1);
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'recall', unitId: 'u-1'),
        );
      },
    );

    test('HQ-32 a recall that runs shows its remaining time and is not '
        'ordered again', () async {
      final far = _field('u-1', metresEast: 100);
      see([far], recalls: {'u-1': const Duration(hours: 4)});

      expect(cubit.recallRemaining('u-1'), const Duration(hours: 3));
      expect(
        cubit.planStore(far),
        const StoreNotPossible(PreCheckRefusal.alreadyRecalled),
      );
      await cubit.storeOrRecall('u-1');

      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice!.refusal, 'already_recalled');
    });

    test('HQ-32 no recall, or an ended one, has no remaining time', () {
      see([_field('u-1')], recalls: {'u-2': const Duration(minutes: 30)});

      expect(cubit.recallRemaining('u-1'), isNull);
      expect(cubit.recallRemaining('u-2'), isNull);
    });

    test(
      'M7.6 orders for a unit that is not the section own do nothing',
      () async {
        see([storedSoldier, redSoldier]);

        await cubit.deploy('r-1');
        await cubit.deploy('nobody');
        await cubit.storeOrRecall('r-1');
        await cubit.storeOrRecall('nobody');

        verifyNever(() => repository.send(any()));
        expect(cubit.state.notice, isNull);
      },
    );

    test('M7.6 a unit not on the field is not stored', () async {
      see([storedSoldier]);

      await cubit.storeOrRecall('s-1');

      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice!.refusal, 'not_on_field');
    });

    test('M7.6 a deploy of a unit that is not stored is not sent', () async {
      see([_field('u-1')]);

      await cubit.deploy('u-1');

      verifyNever(() => repository.send(any()));
      expect(cubit.state.notice!.refusal, 'not_stored');
    });

    test('M7.6 shows the error of an order that could not go out', () async {
      see([storedSoldier]);
      when(() => repository.send(any())).thenThrow(StateError('stopped'));

      await cubit.deploy('s-1');

      expect(cubit.state.notice!.refusal, contains('stopped'));
      expect(log.records.last.level, Level.SEVERE);
      expect(log.records.last.message, 'order deploy failed');
    });

    test('M7.6 drops the answer of an order once closed', () async {
      see([storedSoldier]);
      final answer = Completer<String?>();
      when(() => repository.send(any())).thenAnswer((_) => answer.future);

      final deploy = cubit.deploy('s-1');
      await cubit.close();
      answer.complete(null);
      await deploy;

      expect(cubit.state.notice, isNull);
    });

    test('M7.6 without a battle time nothing is stored or deployed', () async {
      final other = storageCubit(
        snapshots.stream,
        repository: MockBattleRepository(),
        time: null,
      );
      addTearDown(other.close);
      see([storedSoldier, _field('u-1')]);

      expect(
        other.checkDeploy(storedSoldier),
        const PreCheckRefused(PreCheckRefusal.notStored),
      );
      expect(
        other.planStore(_field('u-1')),
        const StoreNotPossible(PreCheckRefusal.notOnField),
      );
      expect(other.lockRemaining, isNull);
      expect(other.recallRemaining('u-1'), isNull);
    });

    test(
      'M7.6 the AP of a unit comes from the repository, only for its own',
      () {
        see([storedSoldier, redSoldier]);

        expect(cubit.apNow(storedSoldier), 30);
        expect(cubit.apNow(redSoldier), isNull);
      },
    );

    test('decision 237 the log names no unit', () async {
      see([storedSoldier, _red('r-1', 20)]);

      await cubit.deploy('s-1');
      see([storedSoldier]);
      await cubit.deploy('s-1');

      expect(log.texts, isNotEmpty);
      for (final text in log.texts) {
        expect(text, isNot(contains('s-1')));
        expect(text, isNot(contains('r-1')));
      }
    });
  });
}
