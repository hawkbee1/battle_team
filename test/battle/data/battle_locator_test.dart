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
    const locator = FixedBattleLocator((battleId: 'pt-1', mapId: 'm'));

    test('M7.12 gives the one battle of the playtest to any account, which '
        'is in it', () async {
      expect(await locator.locate('anyone'), [
        (warId: null, battle: (battleId: 'pt-1', mapId: 'm'), joined: true),
      ]);
    });

    test('M7.12 has no other war to join', () {
      expect(locator.join('w-1'), completes);
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

    group('locate', () {
      test('M7.12 lists every running battle with its war, and marks the one '
          'the account has a section in a team of', () async {
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
            _battle(
              'b-2',
              'w-2',
              teams: {
                'blue': ['s-7'],
              },
              mapId: 'valley',
            ),
          ],
        );

        expect(await locator.locate('a-1'), [
          (
            warId: 'w-1',
            battle: (battleId: 'b-1', mapId: 'saint_lo'),
            joined: true,
          ),
          (
            warId: 'w-2',
            battle: (battleId: 'b-2', mapId: 'valley'),
            joined: false,
          ),
        ]);
      });

      test('M7.12 asks Appwrite for the sections of the account and for the '
          'running battles', () async {
        stubRows();

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
              'status': ['running'],
            },
          ),
        ).called(1);
      });

      test('SOC-30 an account with no section is in no battle, and every '
          'running battle is one it can join', () async {
        stubRows(
          battles: [
            _battle(
              'b-1',
              'w-1',
              teams: {
                'blue': ['s-2'],
              },
            ),
          ],
        );

        final battles = await locator.locate('a-1');

        expect(battles.map((battle) => battle.joined), [false]);
      });

      test('SOC-45 the section of the account in a war is not a section in '
          'the battle of another war with the same ID, and a section of its '
          'war that the battle does not name is not in it', () async {
        stubRows(
          sections: [_section('s-1', 'w-1', 'a-1')],
          battles: [
            // Same section ID, other war.
            _battle(
              'b-9',
              'w-9',
              teams: {
                'blue': ['s-1'],
              },
            ),
            // Its war, but the battle does not name the section.
            _battle(
              'b-1',
              'w-1',
              teams: {
                'blue': ['s-2'],
              },
            ),
          ],
        );

        final battles = await locator.locate('a-1');

        expect(battles.map((battle) => battle.joined), [false, false]);
      });

      test('M7.12 no battle running is an empty list', () async {
        stubRows(sections: [_section('s-1', 'w-1', 'a-1')]);

        expect(await locator.locate('a-1'), isEmpty);
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

      test(
        'M7.12 a row the app cannot read is a failure, and SEVERE',
        () async {
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
        },
      );

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
            _battle('b-other', 'w-other'),
          ],
        );

        await locator.locate('a-secret');

        expect(log.lines, ['INFO running battles found: 2, of the account: 1']);
        for (final text in log.texts) {
          expect(text, isNot(contains('secret')));
          expect(text, isNot(contains('other')));
        }
      });

      test('M7.12 a failed lookup is logged as a WARNING with its kind '
          'only', () async {
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
      });
    });

    group('join', () {
      void stubJoin(int status, Map<String, Object?> body) =>
          when(
            () => apiClient.execute(
              functionId: any(named: 'functionId'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => AppwriteExecution(statusCode: status, body: body),
          );

      test('SOC-30 runs the join of bt_create_war for the war', () async {
        stubJoin(200, {'sectionId': 's-1'});

        await locator.join('w-1');

        verify(
          () => apiClient.execute(
            functionId: AppwriteIds.createWarFunctionId,
            body: {'action': 'join', 'warId': 'w-1'},
          ),
        ).called(1);
      });

      test('SOC-45 an account that is in the war already is in it: no '
          'failure', () async {
        stubJoin(409, {'error': 'already_in_war'});

        await expectLater(locator.join('w-1'), completes);
      });

      test('SOC-30 a war that is over cannot be joined', () async {
        stubJoin(409, {'error': 'war_over'});

        await expectLater(
          locator.join('w-1'),
          throwsA(
            isA<BattleJoinFailure>().having(
              (failure) => failure.reason,
              'reason',
              BattleJoinFailureReason.warOver,
            ),
          ),
        );
      });

      for (final (status, body) in [
        (404, {'error': 'unknown_war'}),
        (401, {'error': 'not_signed_in'}),
        (500, <String, Object?>{}),
      ]) {
        test(
          'M7.12 a refusal $status of the function is another failure',
          () async {
            stubJoin(status, body);

            await expectLater(
              locator.join('w-1'),
              throwsA(
                isA<BattleJoinFailure>().having(
                  (failure) => failure.reason,
                  'reason',
                  BattleJoinFailureReason.other,
                ),
              ),
            );
          },
        );
      }

      for (final (kind, reason) in [
        (AppwriteFailureKind.unreachable, BattleJoinFailureReason.unreachable),
        (AppwriteFailureKind.serverError, BattleJoinFailureReason.other),
      ]) {
        test(
          'M7.12 a function that cannot be run, ${kind.name}, is $reason',
          () async {
            when(
              () => apiClient.execute(
                functionId: any(named: 'functionId'),
                body: any(named: 'body'),
              ),
            ).thenThrow(AppwriteExecutionFailure('failed', kind: kind));

            await expectLater(
              locator.join('w-1'),
              throwsA(
                isA<BattleJoinFailure>().having(
                  (failure) => failure.reason,
                  'reason',
                  reason,
                ),
              ),
            );
          },
        );
      }

      test('decision 237 and M7.12 the logs of a join name no war', () async {
        stubJoin(200, {'sectionId': 's-1'});
        await locator.join('w-secret');
        stubJoin(409, {'error': 'already_in_war'});
        await locator.join('w-secret');
        stubJoin(409, {'error': 'war_over'});
        await expectLater(
          locator.join('w-secret'),
          throwsA(isA<BattleJoinFailure>()),
        );
        stubJoin(500, {});
        await expectLater(
          locator.join('w-secret'),
          throwsA(isA<BattleJoinFailure>()),
        );

        expect(log.lines, [
          'INFO joined a war',
          'INFO the account was in the war already',
          'WARNING join refused: war_over',
          'WARNING join refused: status 500',
        ]);
        for (final text in log.texts) {
          expect(text, isNot(contains('secret')));
        }
      });
    });

    test('M7.12 a lookup failure describes itself', () {
      expect(
        const BattleLookupFailure(unreachable: true).toString(),
        'BattleLookupFailure(unreachable: true)',
      );
    });

    test('M7.12 a join failure describes its reason', () {
      expect(
        const BattleJoinFailure(BattleJoinFailureReason.warOver).toString(),
        'BattleJoinFailure: warOver',
      );
    });
  });
}
