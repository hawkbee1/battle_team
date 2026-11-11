import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:hawkbee_schema/hawkbee_schema.dart';
import 'package:logging/logging.dart';

/// The battle an account plays and its map.
typedef BattleAssignment = ({String battleId, String mapId});

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
/// Finds the battle an account plays (Strategy: from the account's section on
/// Appwrite, or the one battle of the playtest).
/// {@endtemplate}
abstract interface class BattleLocator {
  /// The battle [accountId] plays, or null when its section is in none that
  /// runs.
  ///
  /// Throws a [BattleLookupFailure] when it cannot find out.
  Future<BattleAssignment?> locate(String accountId);
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
  Future<BattleAssignment?> locate(String accountId) async => assignment;
}

/// {@template appwrite_battle_locator}
/// Finds the battle of an account on Appwrite: its sections (`bt_sections`,
/// one per war), then the battle of one of their wars that runs
/// (`bt_battles`) and has the section in one of its teams. Both tables are
/// readable by any signed-in account (M5.18); nothing is written, and the
/// host decides whether the account may enter (decision 220).
///
/// The account's sections may be in several wars: the first battle found
/// wins. Choosing among them waits for the newcomer flow (SOC-03).
/// {@endtemplate}
class AppwriteBattleLocator implements BattleLocator {
  /// {@macro appwrite_battle_locator}
  const new({required this.apiClient});

  /// The Appwrite client the account is signed in with.
  final AppwriteApiClient apiClient;

  static final _log = Logger('battle_team.AppwriteBattleLocator');

  @override
  Future<BattleAssignment?> locate(String accountId) async {
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
        return null;
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
      for (final battle in battles) {
        for (final section in sections) {
          if (section.warId == battle.warId &&
              battle.teams.values.any((ids) => ids.contains(section.id))) {
            _log.info('battle found');
            return (battleId: battle.id, mapId: battle.mapId);
          }
        }
      }
      _log.info('no running battle');
      return null;
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
