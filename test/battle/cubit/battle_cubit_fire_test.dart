import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/log_capture.dart';
import '../../helpers/real_cubit.dart';

/// An enemy 540 m from the rifleman: beyond the rifle's 400 m.
const _farEnemy = UnitView(
  unitId: 'r-far',
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position(50500, 60000, 3000),
);

/// [armedView] with [extra] units in it, and [rifleman] for the rifleman.
SectionView _view({
  UnitView rifleman = blueRifleman,
  List<UnitView> extra = const [],
}) => SectionView(
  weather: 'clear',
  at: armedView.at,
  section: armedView.section,
  units: [blueCommander, rifleman, blueGun, redSoldier, ...extra],
  hqs: armedView.hqs,
  relics: armedView.relics,
  world: armedView.world,
);

/// The rifleman with [ap] AP at hour 1, at 1 AP an hour.
UnitView _rifleman({double ap = 30, Position? at}) => UnitView(
  unitId: 'u-1',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: at ?? blueRifleman.position,
  weapon: 'rifle',
  private: UnitPrivate(
    sightRangeM: 60,
    place: UnitPlace.deployed,
    ap: ApView(value: ap, at: const Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

void main() {
  group('$BattleCubit firing', () {
    late LogCapture log;
    late FakeHost host;
    late BattleCubit cubit;

    setUp(() => log = LogCapture());

    tearDown(() async {
      await log.cancel();
      await cubit.close();
    });

    /// Plays a battle on [view] until the section's view came.
    Future<void> play([SectionView? view]) async {
      host = FakeHost(view: view ?? armedView);
      cubit = realCubit(host);
      await cubit.start();
      await pumpEventQueue(times: 500);
      expect(cubit.state.status, BattleStatus.playing);
    }

    /// The host's next update, which changes [units] of the section.
    Future<void> hostSends(HostMessage message) async {
      host.sockets.single.deliver(message);
      await pumpEventQueue(times: 500);
    }

    group('a target', () {
      test(
        'COMBAT-11 targets a unit of another section that it sees',
        () async {
          await play();
          cubit
            ..select('u-1')
            ..target('r-1');

          expect(cubit.state.targetId, 'r-1');
          expect(cubit.state.target, redSoldier);
        },
      );

      test('COMBAT-11 the same unit again lets the target go', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('r-1')
          ..target('r-1');

        expect(cubit.state.targetId, isNull);
      });

      test('COMBAT-11 a unit of the section is no target', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('c-1');

        expect(cubit.state.targetId, isNull);
      });

      test('COMBAT-11 nothing unseen is a target', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('nobody');

        expect(cubit.state.targetId, isNull);
      });

      test('COMBAT-11 a target needs a unit to fire it', () async {
        await play();

        cubit.target('r-1');

        expect(cubit.state.targetId, isNull);
      });

      test('COMBAT-11 selecting another unit lets the target go', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('r-1')
          ..select('c-1');

        expect(cubit.state.targetId, isNull);
      });

      test(
        'COMBAT-11 a target the section stops seeing is no target',
        () async {
          await play();
          cubit
            ..select('u-1')
            ..target('r-1');

          await hostSends(
            const TickUpdate(at: Duration(hours: 1, seconds: 5), gone: ['r-1']),
          );

          expect(cubit.state.units, isNot(contains('r-1')));
          expect(cubit.state.targetId, isNull);
        },
      );
    });

    group('fire', () {
      test('COMBAT-11 fire needs a seen target', () async {
        await play();
        cubit.select('u-1');

        expect(
          cubit.checkFire(),
          const PreCheckRefused(PreCheckRefusal.targetNotSeen),
        );
        await cubit.fireSelected();

        // Nothing was sent: the host never heard of it.
        expect(host.orders, isEmpty);
        expect(
          cubit.state.notice,
          const OrderNotice(
            order: 'fire',
            unitId: 'u-1',
            refusal: 'target_not_seen',
          ),
        );
      });

      test('COMBAT-11 fires at the target it sees, within range', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('r-1');

        expect(cubit.checkFire(), const PreCheckPassed());
        await cubit.fireSelected();

        expect(host.orders, [const Fire(unitId: 'u-1', targetId: 'r-1')]);
        expect(
          cubit.state.notice,
          const OrderNotice(order: 'fire', unitId: 'u-1'),
        );
      });

      test('COMBAT-11 a target beyond the range is not fired at', () async {
        await play(_view(extra: [_farEnemy]));
        cubit
          ..select('u-1')
          ..target('r-far');

        expect(
          cubit.checkFire(),
          const PreCheckRefused(PreCheckRefusal.outOfRange),
        );
        await cubit.fireSelected();

        expect(host.orders, isEmpty);
        expect(cubit.state.notice?.refusal, 'out_of_range');
      });

      test('COMBAT-06 a shot short of AP waits for them: it is sent', () async {
        await play(_view(rifleman: _rifleman(ap: 0.5)));
        cubit
          ..select('u-1')
          ..target('r-1');

        final check = cubit.checkFire();
        await cubit.fireSelected();

        // 2 AP a shot, 0.5 held and 1 regained an hour: about 1.5 h.
        expect(check, isA<PreCheckPassed>());
        expect(
          (check as PreCheckPassed).apWait,
          allOf(
            greaterThan(const Duration(hours: 1, minutes: 29)),
            lessThanOrEqualTo(const Duration(hours: 1, minutes: 30)),
          ),
        );
        expect(host.orders, [const Fire(unitId: 'u-1', targetId: 'r-1')]);
      });

      test(
        'UNIT-38 an action the unit lacks is refused before sending',
        () async {
          await play();
          // The commander of the fixtures carries no weapon.
          cubit.select('c-1');

          await cubit.fireSelected();
          await cubit.reload();

          expect(host.orders, isEmpty);
          expect(cubit.state.notice?.refusal, 'no_weapon');
          expect(
            cubit.checkFireAtPosition(),
            const PreCheckRefused(PreCheckRefusal.noWeapon),
          );
          expect(cubit.magazineOf(blueCommander), isNull);
        },
      );

      test('M7.5 sends nothing before it plays', () async {
        host = FakeHost(view: armedView);
        cubit = realCubit(host);

        await cubit.reload();
        await cubit.fireSelected();

        expect(cubit.state.status, BattleStatus.signingIn);
        expect(host.orders, isEmpty);
        expect(cubit.state.notice, isNull);
      });

      test('M7.5 the checks refuse for a unit that is not selected', () async {
        await play();

        const none = PreCheckRefused(PreCheckRefusal.notOnField);
        expect(cubit.checkFire(), none);
        expect(cubit.checkFireAtPosition(), none);
        expect(cubit.checkFireAimed(), none);
        expect(cubit.checkReload(), none);
        expect(cubit.checkSwap('machine_gun'), none);
        expect(cubit.swappableWeapons, isEmpty);
      });
    });

    group('fire at a position', () {
      test('COMBAT-12 fire at position for indirect-fire units only', () async {
        await play();
        cubit
          ..select('u-1')
          ..toggleGroundFire();

        // The rifle fires at what it sees, not at the ground.
        expect(
          cubit.checkFireAtPosition(),
          const PreCheckRefused(PreCheckRefusal.notIndirect),
        );
        expect(cubit.state.groundFire, isFalse);
      });

      test(
        'COMBAT-12 the artillery arms the next tap, and fires there',
        () async {
          await play();
          cubit
            ..select('g-1')
            ..toggleGroundFire();
          expect(cubit.state.groundFire, isTrue);
          const there = Position(51500, 6000, 3000);

          await cubit.fireSelectedAt(there);

          expect(host.orders, [
            const FireAtPosition(unitId: 'g-1', target: there),
          ]);
          // One tap, one shot.
          expect(cubit.state.groundFire, isFalse);
          expect(cubit.state.notice?.order, 'fireAtPosition');
        },
      );

      test('COMBAT-12 arming twice disarms', () async {
        await play();
        cubit
          ..select('g-1')
          ..toggleGroundFire()
          ..toggleGroundFire();

        expect(cubit.state.groundFire, isFalse);
      });

      test('COMBAT-12 a position beyond the range is not fired at', () async {
        await play();
        cubit
          ..select('g-1')
          ..toggleGroundFire();

        // The artillery reaches 1,200 m: this is 2,000 m away.
        await cubit.fireSelectedAt(const Position(250500, 6000, 3000));

        expect(host.orders, isEmpty);
        expect(cubit.state.notice?.refusal, 'out_of_range');
        expect(cubit.state.groundFire, isFalse);
      });

      test('COMBAT-12 selecting another unit disarms', () async {
        await play();
        cubit
          ..select('g-1')
          ..toggleGroundFire()
          ..select('u-1');

        expect(cubit.state.groundFire, isFalse);
      });
    });

    group('fire aimed', () {
      final aim = Direction.of(0, -1, 0.05);

      test('COMBAT-14 aimed fire from first person sends FireAimed with the '
          "camera's direction", () async {
        await play();
        cubit
          ..select('u-1')
          ..enterFirstPerson();
        expect(cubit.state.viewMode, const FirstPersonMode('u-1'));
        expect(cubit.checkFireAimed(), const PreCheckPassed());

        await cubit.fireAimed(aim);

        final order = host.orders.single as FireAimed;
        expect(order.unitId, 'u-1');
        expect(order.aim, aim);
        // The battle time the player fired at, as the client shows it.
        expect(order.fireTime, greaterThanOrEqualTo(armedView.at));
        expect(cubit.state.notice?.order, 'fireAimed');
      });

      test('COMBAT-14 from above there is no aim to fire along', () async {
        await play();
        cubit.select('u-1');

        await cubit.fireAimed(aim);

        expect(host.orders, isEmpty);
        expect(cubit.state.notice, isNull);
      });

      test(
        'decision 183 artillery does not fly: it is not fired aimed',
        () async {
          await play();
          cubit
            ..select('g-1')
            ..enterFirstPerson();

          await cubit.fireAimed(aim);

          expect(host.orders, isEmpty);
          expect(cubit.state.notice?.refusal, 'not_aimed');
        },
      );
    });

    group('reload and swap', () {
      test(
        'COMBAT-33 reloads, and the panel follows the next UnitPrivate',
        () async {
          await play();
          cubit.select('u-1');
          expect(cubit.magazineOf(cubit.state.selected!), 10);

          await cubit.reload();
          expect(host.orders, [const Reload(unitId: 'u-1')]);
          expect(cubit.state.notice?.order, 'reload');

          // The host's next update: a full magazine, busy for 3 s.
          final reloaded = UnitView(
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
              rounds: 10,
              xpEarned: 0,
              xpUnspent: 0,
              busyUntil: armedView.at + const Duration(seconds: 3),
            ),
          );
          await hostSends(
            TickUpdate(
              at: armedView.at + const Duration(seconds: 1),
              ownUnits: [reloaded],
            ),
          );

          expect(
            cubit.state.selected?.private?.busyUntil,
            armedView.at + const Duration(seconds: 3),
          );
        },
      );

      test('COMBAT-28 swaps for a spare weapon at the storage place', () async {
        await play();
        cubit.select('u-1');

        expect(cubit.state.storedWeapons, ['machine_gun']);
        expect(cubit.swappableWeapons, ['machine_gun']);
        expect(cubit.checkSwap('machine_gun'), const PreCheckPassed());
        await cubit.swap('machine_gun');

        expect(host.orders, [
          const SwapWeapon(unitId: 'u-1', weapon: 'machine_gun'),
        ]);

        // The host's next update: the new weapon, unloaded, busy for 5 s.
        final swapped = UnitView(
          unitId: 'u-1',
          unitType: 'soldier',
          sectionId: 's-blue',
          team: 'blue',
          hp: 100,
          maxHp: 100,
          position: blueRifleman.position,
          weapon: 'machine_gun',
          private: UnitPrivate(
            sightRangeM: 60,
            place: UnitPlace.deployed,
            ap: blueRifleman.private!.ap,
            morale: 100,
            rounds: 0,
            xpEarned: 0,
            xpUnspent: 0,
            busyUntil: armedView.at + const Duration(seconds: 5),
          ),
        );
        await hostSends(
          TickUpdate(
            at: armedView.at + const Duration(seconds: 1),
            ownUnits: [swapped],
            section: const SectionPrivate(
              money: 0,
              xp: 0,
              storedWeapons: ['rifle'],
            ),
          ),
        );

        expect(cubit.state.selected?.weapon, 'machine_gun');
        expect(cubit.state.selected?.private?.rounds, 0);
        expect(cubit.state.storedWeapons, ['rifle']);
      });

      test('COMBAT-28 away from the storage place it is refused', () async {
        await play(
          _view(
            // 100 m from the HQ.
            rifleman: _rifleman(at: const Position(50500, 15500, 3000)),
          ),
        );
        cubit.select('u-1');

        await cubit.swap('machine_gun');

        expect(host.orders, isEmpty);
        expect(cubit.state.notice?.refusal, 'not_at_storage');
      });

      test(
        'COMBAT-26 a weapon the unit type may not use is not offered',
        () async {
          await play();
          cubit.select('g-1');

          // The artillery piece uses artillery only.
          expect(cubit.swappableWeapons, isEmpty);
          await cubit.swap('machine_gun');

          expect(host.orders, isEmpty);
          expect(cubit.state.notice?.refusal, 'not_allowed');
        },
      );

      test(
        'decision 151 a weapon the storage does not hold is refused',
        () async {
          await play();
          cubit.select('u-1');

          await cubit.swap('rifle');

          expect(host.orders, isEmpty);
          expect(cubit.state.notice?.refusal, 'not_in_storage');
        },
      );
    });

    group('the log', () {
      test('decision 237 says what was not sent, and names no unit', () async {
        await play();
        cubit
          ..select('u-1')
          ..target('r-1');
        await cubit.reload();
        await cubit.fireAimed(Direction.of(0, -1, 0));
        cubit.select('c-1');
        await cubit.fireSelected();

        final lines = log.lines;
        expect(lines, contains('INFO order reload sent'));
        expect(lines, contains('INFO order reload accepted'));
        expect(lines, contains('WARNING order fire not sent: no_weapon'));
        // Not a unit, a position or a direction in any record.
        expect(
          log.texts.join('\n'),
          allOf(
            isNot(contains('u-1')),
            isNot(contains('r-1')),
            isNot(contains('c-1')),
            isNot(contains('50500')),
          ),
        );
      });
    });
  });
}
