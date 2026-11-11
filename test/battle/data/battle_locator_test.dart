import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/battle/battle.dart' hide BattleStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:hawkbee_schema/hawkbee_schema.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

const _kept = KeptSection(money: 500, xp: 0);

AppwriteRow _section(String id, String warId, String accountId) => AppwriteRow(
  id: id,
  data: SectionRow(
    id: id,
    warId: warId,
    accountId: accountId,
    kept: _kept,
  ).toData(),
);

AppwriteRow _battle(
  String id,
  String warId, {
  Map<String, List<String>> teams = const {},
  String mapId = 'saint_lo_1km',
}) => AppwriteRow(
  id: id,
  data: BattleRow(
    id: id,
    warId: warId,
    mapId: mapId,
    seed: 7,
    status: BattleStatus.running,
    teams: teams,
  ).toData(),
);

void main() {
  group(FixedBattleLocator, () {
    test('M7.12 gives the one battle of the playtest to any account', () async {
      const locator = FixedBattleLocator((battleId: 'pt-1', mapId: 'm'));

      expect(await locator.locate('anyone'), [
        (warId: null, battle: (battleId: 'pt-1', mapId: 'm')),
      ]);
    });
  });

  group(AppwriteBattleLocator, () {
    late MockAppwriteApiClient apiClient;
    late AppwriteBattleLocator locator;
    late LogCapture log;

    setUp(() {
      apiClient = MockAppwriteApiClient();
      locator = AppwriteBattleLocator(apiClient: apiClient);
      log = LogCapture();
    });

    tearDown(() => log.cancel());

    void stubRows({
      List<AppwriteRow> sections = const [],
      List<AppwriteRow> battles = const [],
    }) {
      when(
        () => apiClient.findRows(
          databaseId: any(named: 'databaseId'),
          tableId: AppwriteIds.sectionsTableId,
          equal: any(named: 'equal'),
        ),
      ).thenAnswer((_) async => sections);
      when(
        () => apiClient.findRows(
          databaseId: any(named: 'databaseId'),
          tableId: AppwriteIds.battlesTableId,
          equal: any(named: 'equal'),
        ),
      ).thenAnswer((_) async => battles);
    }

    test('M7.12 finds the running battle that has the section of the '
        'account in a team, and its map', () async {
      stubRows(
        sections: [_section('s-1', 'w-1', 'a-1')],
        battles: [
          _battle(
            'b-1',
            'w-1',
            teams: {
              'blue': ['s-2'],
              'red': ['s-1'],
            },
            mapId: 'saint_lo',
          ),
        ],
      );

      expect(await locator.locate('a-1'), [
        (warId: 'w-1', battle: (battleId: 'b-1', mapId: 'saint_lo')),
      ]);
    });

    test('M7.12 asks Appwrite for the sections of the account, then for the '
        'running battles of their wars', () async {
      stubRows(
        sections: [
          _section('s-1', 'w-1', 'a-1'),
          _section('s-2', 'w-2', 'a-1'),
        ],
      );

      await locator.locate('a-1');

      verify(
        () => apiClient.findRows(
          databaseId: AppwriteIds.databaseId,
          tableId: AppwriteIds.sectionsTableId,
          equal: {
            'account_id': ['a-1'],
          },
        ),
      ).called(1);
      verify(
        () => apiClient.findRows(
          databaseId: AppwriteIds.databaseId,
          tableId: AppwriteIds.battlesTableId,
          equal: {
            'war_id': ['w-1', 'w-2'],
            'status': ['running'],
          },
        ),
      ).called(1);
    });

    test('M7.12 an account with no section has no battle, and the battles '
        'are not asked', () async {
      stubRows();

      expect(await locator.locate('a-1'), isEmpty);
      verifyNever(
        () => apiClient.findRows(
          databaseId: any(named: 'databaseId'),
          tableId: AppwriteIds.battlesTableId,
          equal: any(named: 'equal'),
        ),
      );
    });

    test('M7.12 a battle that runs without the section of the account is '
        'not its battle', () async {
      stubRows(
        sections: [_section('s-1', 'w-1', 'a-1')],
        battles: [
          _battle(
            'b-1',
            'w-1',
            teams: {
              'blue': ['s-2'],
            },
          ),
          // The section's id in a battle of another war is not it either.
          _battle(
            'b-2',
            'w-9',
            teams: {
              'blue': ['s-1'],
            },
          ),
        ],
      );

      expect(await locator.locate('a-1'), isEmpty);
    });

    test('M7.12 with sections in several wars, every running battle is '
        'listed with its war, in the order of the table', () async {
      stubRows(
        sections: [
          _section('s-1', 'w-1', 'a-1'),
          _section('s-2', 'w-2', 'a-1'),
        ],
        battles: [
          _battle(
            'b-2',
            'w-2',
            teams: {
              'red': ['s-2'],
            },
          ),
          _battle(
            'b-1',
            'w-1',
            teams: {
              'blue': ['s-1'],
            },
          ),
        ],
      );

      expect(await locator.locate('a-1'), [
        (warId: 'w-2', battle: (battleId: 'b-2', mapId: 'saint_lo_1km')),
        (warId: 'w-1', battle: (battleId: 'b-1', mapId: 'saint_lo_1km')),
      ]);
    });

    for (final (kind, unreachable) in [
      (AppwriteFailureKind.unreachable, true),
      (AppwriteFailureKind.serverError, false),
      (AppwriteFailureKind.unauthorized, false),
    ]) {
      test('M7.12 a ${kind.name} failure of the lookup is a '
          '$BattleLookupFailure (unreachable: $unreachable)', () async {
        when(
          () => apiClient.findRows(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            equal: any(named: 'equal'),
          ),
        ).thenThrow(AppwriteRowsFailure('failed', kind: kind));

        await expectLater(
          locator.locate('a-1'),
          throwsA(
            isA<BattleLookupFailure>().having(
              (failure) => failure.unreachable,
              'unreachable',
              unreachable,
            ),
          ),
        );
      });
    }

    test('M7.12 a row the app cannot read is a failure, and SEVERE', () async {
      stubRows(
        sections: [
          const AppwriteRow(id: 's-1', data: {'war_id': 1}),
        ],
      );

      await expectLater(
        locator.locate('a-1'),
        throwsA(
          isA<BattleLookupFailure>().having(
            (failure) => failure.unreachable,
            'unreachable',
            isFalse,
          ),
        ),
      );
      expect(log.lines, ['SEVERE lookup failed: a row is not readable']);
    });

    test('decision 237 and M7.12 log no account, section, battle or war '
        'ID', () async {
      stubRows(
        sections: [_section('s-secret', 'w-secret', 'a-secret')],
        battles: [
          _battle(
            'b-secret',
            'w-secret',
            teams: {
              'blue': ['s-secret'],
            },
          ),
        ],
      );

      await locator.locate('a-secret');

      expect(log.lines, ['INFO running battles found: 1']);
      for (final text in log.texts) {
        expect(text, isNot(contains('secret')));
      }
    });

    test('M7.12 says no section and no running battle apart, in the log '
        'only', () async {
      stubRows();
      await locator.locate('a-1');
      stubRows(sections: [_section('s-1', 'w-1', 'a-1')]);
      await locator.locate('a-1');

      expect(log.lines, ['INFO no section', 'INFO running battles found: 0']);
    });

    test(
      'M7.12 a failed lookup is logged as a WARNING with its kind only',
      () async {
        when(
          () => apiClient.findRows(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            equal: any(named: 'equal'),
          ),
        ).thenThrow(
          const AppwriteRowsFailure('x', kind: AppwriteFailureKind.unreachable),
        );

        await expectLater(
          locator.locate('a-1'),
          throwsA(isA<BattleLookupFailure>()),
        );

        expect(log.lines, ['WARNING lookup failed: unreachable']);
      },
    );

    test('M7.12 a lookup failure describes itself', () {
      expect(
        const BattleLookupFailure(unreachable: true).toString(),
        'BattleLookupFailure(unreachable: true)',
      );
    });
  });
}
