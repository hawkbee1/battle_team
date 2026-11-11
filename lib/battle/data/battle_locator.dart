import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:hawkbee_schema/hawkbee_schema.dart';
import 'package:logging/logging.dart';

/// The battle an account plays and its map.
typedef BattleAssignment = ({String battleId, String mapId});

/// A running battle, the war it belongs to (null when the locator does not
/// know it, as the playtest's) and whether the account has a section in it.
typedef AccountBattle = ({String? warId, BattleAssignment battle, bool joined});

/// {@template battle_lookup_failure}
/// Thrown by a [BattleLocator] when it cannot say which battles are running.
/// The screen says it in words; [unreachable] tells whether the server did
/// not answer.
/// {@endtemplate}
class BattleLookupFailure implements Exception {
  /// {@macro battle_lookup_failure}
  const new({required this.unreachable});

  /// Whether the server did not answer, rather than refused or failed.
  final bool unreachable;

  @override
  String toString() => 'BattleLookupFailure(unreachable: $unreachable)';
}

/// Why a war could not be joined.
enum BattleJoinFailureReason {
  /// The war has ended.
  warOver,

  /// The server did not answer.
  unreachable,

  /// Anything else.
  other,
}

/// {@template battle_join_failure}
/// Thrown by a [BattleLocator] when the account cannot join a war.
/// {@endtemplate}
class BattleJoinFailure implements Exception {
  /// {@macro battle_join_failure}
  const new(this.reason);

  /// Why it could not.
  final BattleJoinFailureReason reason;

  @override
  String toString() => 'BattleJoinFailure: ${reason.name}';
}

/// {@template battle_locator}
/// Finds the running battles and joins their wars (Strategy: on Appwrite, or
/// the one battle of the playtest).
/// {@endtemplate}
abstract interface class BattleLocator {
  /// Every running battle, one per war, each with whether [accountId] has a
  /// section in it; empty when no battle runs.
  ///
  /// Throws a [BattleLookupFailure] when it cannot find out.
  Future<List<AccountBattle>> locate(String accountId);

  /// Joins the war [warId] with a new section (SOC-30): the section is in the
  /// battle that runs, and the host admits it at its next look. Completes
  /// when the account has a section in the war, also when it had one.
  ///
  /// Throws a [BattleJoinFailure] when it cannot.
  Future<void> join(String warId);
}

/// {@template fixed_battle_locator}
/// The playtest's [BattleLocator]: always [assignment], whoever signed in,
/// since `tool/playtest.dart` set that battle up. There is no other war to
/// join.
/// {@endtemplate}
class FixedBattleLocator implements BattleLocator {
  /// {@macro fixed_battle_locator}
  const new(this.assignment);

  /// The battle every account plays.
  final BattleAssignment assignment;

  @override
  Future<List<AccountBattle>> locate(String accountId) async => [
    (warId: null, battle: assignment, joined: true),
  ];

  @override
  Future<void> join(String warId) async {}
}

/// {@template appwrite_battle_locator}
/// Finds the battles on Appwrite: every running battle (`bt_battles`), and
/// the account's sections (`bt_sections`, one per war) to tell the battles it
/// has a section in a team of. Both tables are readable by any signed-in
/// account (M5.18); the host decides whether the account may enter (decision
/// 220).
///
/// [join] runs the backend's `bt_create_war` function (`join`): it creates the
/// account's section with the war's starting money and a commander, in the
/// weakest team of the running battle (SOC-02, SOC-30, SOC-45), and nothing is
/// written by the app itself.
/// {@endtemplate}
class AppwriteBattleLocator implements BattleLocator {
  /// {@macro appwrite_battle_locator}
  const new({required this.apiClient});

  /// The Appwrite client the account is signed in with.
  final AppwriteApiClient apiClient;

  static final _log = Logger('battle_team.AppwriteBattleLocator');

  @override
  Future<List<AccountBattle>> locate(String accountId) async {
    try {
      final sections = [
        for (final row in await apiClient.findRows(
          databaseId: AppwriteIds.databaseId,
          tableId: AppwriteIds.sectionsTableId,
          equal: {
            'account_id': [accountId],
          },
        ))
          SectionRow.fromData(row.id, row.data),
      ];
      final battles = [
        for (final row in await apiClient.findRows(
          databaseId: AppwriteIds.databaseId,
          tableId: AppwriteIds.battlesTableId,
          equal: {
            'status': [BattleStatus.running.name],
          },
        ))
          BattleRow.fromData(row.id, row.data),
      ];
      final found = <AccountBattle>[
        for (final battle in battles)
          (
            warId: battle.warId,
            battle: (battleId: battle.id, mapId: battle.mapId),
            joined: sections.any(
              (section) =>
                  section.warId == battle.warId &&
                  battle.teams.values.any((ids) => ids.contains(section.id)),
            ),
          ),
      ];
      _log.info(
        'running battles found: ${found.length}, '
        'of the account: ${found.where((battle) => battle.joined).length}',
      );
      return found;
    } on AppwriteRowsFailure catch (failure) {
      _log.warning('lookup failed: ${failure.kind.name}', failure);
      throw BattleLookupFailure(
        unreachable: failure.kind == AppwriteFailureKind.unreachable,
      );
    } on FormatException catch (error, stackTrace) {
      // A row the app cannot read: the schema moved on.
      _log.severe('lookup failed: a row is not readable', error, stackTrace);
      throw const BattleLookupFailure(unreachable: false);
    }
  }

  @override
  Future<void> join(String warId) async {
    final AppwriteExecution answer;
    try {
      answer = await apiClient.execute(
        functionId: AppwriteIds.createWarFunctionId,
        body: {'action': 'join', 'warId': warId},
      );
    } on AppwriteExecutionFailure catch (failure) {
      _log.warning('join failed: ${failure.kind.name}', failure);
      throw BattleJoinFailure(
        failure.kind == AppwriteFailureKind.unreachable
            ? BattleJoinFailureReason.unreachable
            : BattleJoinFailureReason.other,
      );
    }
    if (answer.statusCode == 200) {
      _log.info('joined a war');
      return;
    }
    switch (answer.body['error']) {
      // A section joined from another device: the account is in the war.
      case 'already_in_war':
        _log.info('the account was in the war already');
      case 'war_over':
        _log.warning('join refused: war_over');
        throw const BattleJoinFailure(BattleJoinFailureReason.warOver);
      case _:
        _log.warning('join refused: status ${answer.statusCode}');
        throw const BattleJoinFailure(BattleJoinFailureReason.other);
    }
  }
}
