import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:hawkbee_schema/hawkbee_schema.dart';
import 'package:logging/logging.dart';

/// The battle an account plays and its map.
typedef BattleAssignment = ({String battleId, String mapId});

/// A running battle the account has a section in, and the war it belongs to
/// (null when the locator does not know it, as the playtest's).
typedef AccountBattle = ({String? warId, BattleAssignment battle});

/// {@template battle_lookup_failure}
/// Thrown by a [BattleLocator] when it cannot say which battle an account
/// plays. The screen says it in words; [unreachable] tells whether the server
/// did not answer.
/// {@endtemplate}
class BattleLookupFailure implements Exception {
  /// {@macro battle_lookup_failure}
  const new({required this.unreachable});

  /// Whether the server did not answer, rather than refused or failed.
  final bool unreachable;

  @override
  String toString() => 'BattleLookupFailure(unreachable: $unreachable)';
}

/// {@template battle_locator}
/// Finds the battles an account plays (Strategy: from the account's sections
/// on Appwrite, or the one battle of the playtest).
/// {@endtemplate}
abstract interface class BattleLocator {
  /// The running battles [accountId] has a section in, one per war; empty when
  /// its sections are in none that runs.
  ///
  /// Throws a [BattleLookupFailure] when it cannot find out.
  Future<List<AccountBattle>> locate(String accountId);
}

/// {@template fixed_battle_locator}
/// The playtest's [BattleLocator]: always [assignment], whoever signed in,
/// since `tool/playtest.dart` set that battle up.
/// {@endtemplate}
class FixedBattleLocator implements BattleLocator {
  /// {@macro fixed_battle_locator}
  const new(this.assignment);

  /// The battle every account plays.
  final BattleAssignment assignment;

  @override
  Future<List<AccountBattle>> locate(String accountId) async => [
    (warId: null, battle: assignment),
  ];
}

/// {@template appwrite_battle_locator}
/// Finds the battles of an account on Appwrite: its sections (`bt_sections`,
/// one per war), then the battles of their wars that run (`bt_battles`) and
/// have the section in one of their teams. Both tables are readable by any
/// signed-in account (M5.18); nothing is written, and the host decides whether
/// the account may enter (decision 220).
///
/// An account in several wars gets a battle for each that runs one: the player
/// chooses (`BattleEntryPage`).
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
      if (sections.isEmpty) {
        _log.info('no section');
        return const [];
      }
      final battles = [
        for (final row in await apiClient.findRows(
          databaseId: AppwriteIds.databaseId,
          tableId: AppwriteIds.battlesTableId,
          equal: {
            'war_id': [for (final section in sections) section.warId],
            'status': [BattleStatus.running.name],
          },
        ))
          BattleRow.fromData(row.id, row.data),
      ];
      final found = <AccountBattle>[
        for (final battle in battles)
          if (sections.any(
            (section) =>
                section.warId == battle.warId &&
                battle.teams.values.any((ids) => ids.contains(section.id)),
          ))
            (
              warId: battle.warId,
              battle: (battleId: battle.id, mapId: battle.mapId),
            ),
      ];
      _log.info('running battles found: ${found.length}');
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
}
