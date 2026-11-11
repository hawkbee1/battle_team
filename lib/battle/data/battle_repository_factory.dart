import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/battle/data/battle_locator.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:battle_team/battle/data/battle_settings.dart';

/// {@template battle_repository_factory}
/// Makes the [BattleRepository] of a battle (Factory). A repository serves one
/// session, so each battle an account enters, and each sign-in after a
/// log-out, gets its own.
/// {@endtemplate}
class BattleRepositoryFactory {
  /// {@macro battle_repository_factory}
  const new({
    required this.apiClient,
    required this.endpoint,
    required this.projectId,
  });

  /// The Appwrite client the account is signed in with.
  final AppwriteApiClient apiClient;

  /// The Appwrite API, `…/v1`.
  final String endpoint;

  /// The Appwrite project.
  final String projectId;

  /// The repository of [assignment], not started.
  BattleRepository create(BattleAssignment assignment) => BattleRepository(
    settings: BattleSettings(
      endpoint: endpoint,
      projectId: projectId,
      battleId: assignment.battleId,
      mapId: assignment.mapId,
    ),
    apiClient: apiClient,
  );
}
