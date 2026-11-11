import 'package:battle_team/battle/battle.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const BattleAssignment _assignment = (battleId: 'b-1', mapId: 'saint_lo_1km');

void main() {
  group(BattleEntryCubit, () {
    late MockBattleLocator locator;

    setUp(() {
      locator = MockBattleLocator();
    });

    BattleEntryCubit build() =>
        BattleEntryCubit(locator: locator, accountId: 'a-1');

    test('M7.12 starts looking', () {
      expect(build().state, const BattleEntryLocating());
    });

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 finds the battle of the account',
      setUp: () =>
          when(() => locator.locate('a-1'))
              .thenAnswer((_) async => _assignment),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [
        BattleEntryLocating(),
        BattleEntryFound(_assignment),
      ],
    );

    blocTest<BattleEntryCubit, BattleEntryState>(
      'M7.12 an account with no running battle has none',
      setUp: () =>
          when(() => locator.locate('a-1')).thenAnswer((_) async => null),
      build: build,
      act: (cubit) => cubit.locate(),
      expect: () => const [BattleEntryLocating(), BattleEntryNone()],
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
          return _assignment;
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
        const BattleEntryFailed(unreachable: true),
        isNot(const BattleEntryFailed(unreachable: false)),
      );
    });
  });
}
