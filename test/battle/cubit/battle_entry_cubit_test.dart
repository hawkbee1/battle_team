import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo_1km');
const AccountBattle _first = (warId: 'w-1', battle: _assignment);
const AccountBattle _second = (
  warId: 'w-2',
  battle: (battleId: 'b-2', mapId: 'valley'),
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

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 enters at once the only battle of the account',
      setUp: () => stubBattles(const [_first]),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryFound(_assignment),
      ],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 lets the player choose among several battles, one per war',
      setUp: () => stubBattles(const [_first, _second]),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryChoosing([_first, _second]),
      ],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 an account with no running battle has none',
      setUp: () => stubBattles(const []),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [BattleEntryLocating(), BattleEntryNone()],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 switching lists the battles even when there is only one',
      setUp: () => stubBattles(const [_first]),
      build: build,
      act: (cubit) => cubit.choose(),
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryChoosing([_first]),
      ],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 switching with no running battle says there is none',
      setUp: () => stubBattles(const []),
      build: build,
      act: (cubit) => cubit.choose(),
      expect: () => const [BattleEntryLocating(), BattleEntryNone()],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 enters the battle the player picked',
      setUp: () => stubBattles(const [_first, _second]),
      build: build,
      act: (cubit) async {
        await cubit.locate();
        cubit.enter(_second);
      },
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryChoosing([_first, _second]),
        BattleEntryFound((battleId: 'b-2', mapId: 'valley')),
      ],
    );

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
          return const [_first];
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
        const BattleEntryChoosing([_first]),
        isNot(const BattleEntryChoosing([_second])),
      );
      expect(
        const BattleEntryFailed(unreachable: true),
        isNot(const BattleEntryFailed(unreachable: false)),
      );
    });
  });
}
