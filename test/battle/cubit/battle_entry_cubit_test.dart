import 'dart:async';

import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo_1km');

/// A battle the account is in, and one it can join.
const AccountBattle _mine = (warId: 'w-1', battle: _assignment, joined: true);
const AccountBattle _other = (
  warId: 'w-2',
  battle: (battleId: 'b-2', mapId: 'valley'),
  joined: false,
);
const AccountBattle _third = (
  warId: 'w-3',
  battle: (battleId: 'b-3', mapId: 'valley'),
  joined: true,
);

void main() {
  group(BattleEntryCubit, () {
    late MockBattleLocator locator;

    setUp(() {
      locator = MockBattleLocator();
    });

    BattleEntryCubit build() =>
        BattleEntryCubit(locator: locator, accountId: 'a-1');

    void stubBattles(List<AccountBattle> battles) =>
        when(() => locator.locate('a-1')).thenAnswer((_) async => battles);

    test('M7.12 starts looking', () {
      expect(build().state, const BattleEntryLocating());
    });

    group('on arrival', () {
      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 enters at once the only battle the account is in, though '
        'others run',
        setUp: () => stubBattles(const [_other, _mine]),
        build: build,
        act: (cubit) => cubit.locate(),
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryFound(_assignment),
        ],
      );

      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 lets the player choose when the account is in several',
        setUp: () => stubBattles(const [_mine, _third, _other]),
        build: build,
        act: (cubit) => cubit.locate(),
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryChoosing([_mine, _third, _other]),
        ],
      );

      blocTest<BattleEntryCubit, BattleEntryState>(
        'SOC-30 lets the player choose when the account is in no battle but '
        'some run: he can join one',
        setUp: () => stubBattles(const [_other]),
        build: build,
        act: (cubit) => cubit.locate(),
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryChoosing([_other]),
        ],
      );

      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 says there is none when no battle runs',
        setUp: () => stubBattles(const []),
        build: build,
        act: (cubit) => cubit.locate(),
        expect: () => const [BattleEntryLocating(), BattleEntryNone()],
      );
    });

    group('switching', () {
      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 lists the running battles even when the account is in only '
        'one',
        setUp: () => stubBattles(const [_mine, _other]),
        build: build,
        act: (cubit) => cubit.choose(),
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryChoosing([_mine, _other]),
        ],
      );

      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 says there is none when no battle runs',
        setUp: () => stubBattles(const []),
        build: build,
        act: (cubit) => cubit.choose(),
        expect: () => const [BattleEntryLocating(), BattleEntryNone()],
      );
    });

    group('entering', () {
      blocTest<BattleEntryCubit, BattleEntryState>(
        'M7.12 enters at once a battle the account is in, and joins nothing',
        setUp: () => stubBattles(const [_mine, _third]),
        build: build,
        act: (cubit) async {
          await cubit.locate();
          await cubit.enter(_third);
        },
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryChoosing([_mine, _third]),
          BattleEntryFound((battleId: 'b-3', mapId: 'valley')),
        ],
        verify: (_) => verifyNever(() => locator.join(any())),
      );

      blocTest<BattleEntryCubit, BattleEntryState>(
        'SOC-30 joins the war of a battle the account is not in, then enters '
        'it',
        setUp: () {
          stubBattles(const [_mine, _other]);
          when(() => locator.join('w-2')).thenAnswer((_) async {});
        },
        build: build,
        act: (cubit) async {
          await cubit.choose();
          await cubit.enter(_other);
        },
        expect: () => const [
          BattleEntryLocating(),
          BattleEntryChoosing([_mine, _other]),
          BattleEntryJoining(_other),
          BattleEntryFound((battleId: 'b-2', mapId: 'valley')),
        ],
        verify: (_) => verify(() => locator.join('w-2')).called(1),
      );

      for (final reason in BattleJoinFailureReason.values) {
        blocTest<BattleEntryCubit, BattleEntryState>(
          'SOC-30 a war that cannot be joined (${reason.name}) goes back to '
          'the list with the reason, and enters nothing',
          setUp: () {
            stubBattles(const [_mine, _other]);
            when(() => locator.join('w-2'))
                .thenThrow(BattleJoinFailure(reason));
          },
          build: build,
          act: (cubit) async {
            await cubit.choose();
            await cubit.enter(_other);
          },
          expect: () => [
            const BattleEntryLocating(),
            const BattleEntryChoosing([_mine, _other]),
            const BattleEntryJoining(_other),
            BattleEntryChoosing(const [_mine, _other], problem: reason),
          ],
        );
      }
    });

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 says whether the server did not answer',
      setUp: () =>
          when(() => locator.locate('a-1'))
              .thenThrow(const BattleLookupFailure(unreachable: true)),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryFailed(unreachable: true),
      ],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 looks again after a failure',
      setUp: () {
        var calls = 0;
        when(() => locator.locate('a-1')).thenAnswer((_) async {
          if (++calls == 1) {
            throw const BattleLookupFailure(unreachable: false);
          }
          return const [_mine];
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.locate();
        await cubit.locate();
      },
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryFailed(unreachable: false),
        BattleEntryLocating(),
        BattleEntryFound(_assignment),
      ],
    );

    test('M7.12 states with the same content are equal', () {
      expect(
        const BattleEntryFound(_assignment),
        const BattleEntryFound(_assignment),
      );
      expect(
        const BattleEntryChoosing([_mine]),
        isNot(const BattleEntryChoosing([_other])),
      );
      expect(
        const BattleEntryChoosing([_mine]),
        isNot(
          const BattleEntryChoosing([
            _mine,
          ], problem: BattleJoinFailureReason.warOver),
        ),
      );
      expect(
        const BattleEntryJoining(_other),
        const BattleEntryJoining(_other),
      );
      expect(
        const BattleEntryFailed(unreachable: true),
        isNot(const BattleEntryFailed(unreachable: false)),
      );
    });

    test('M7.12 a battle joined while the player waits is entered only '
        'after the join', () async {
      stubBattles(const [_other]);
      final joined = Completer<void>();
      when(() => locator.join('w-2')).thenAnswer((_) => joined.future);
      final cubit = build();
      await cubit.choose();

      final entering = cubit.enter(_other);
      await pumpEventQueue();
      expect(cubit.state, const BattleEntryJoining(_other));

      joined.complete();
      await entering;
      expect(
        cubit.state,
        const BattleEntryFound((battleId: 'b-2', mapId: 'valley')),
      );
    });
  });
}
