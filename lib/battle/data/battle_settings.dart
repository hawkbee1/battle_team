import 'package:equatable/equatable.dart';

/// {@template battle_settings}
/// Where one battle is played: the Appwrite project that finds its host, the
/// battle and its map. The battle comes from the account's section
/// (`BattleLocator`), or from the playtest's env file (`PlaytestSettings`).
/// {@endtemplate}
class BattleSettings extends Equatable {
  /// {@macro battle_settings}
  const new({
    required this.endpoint,
    required this.projectId,
    required this.battleId,
    this.mapId = 'saint_lo_1km',
  });

  /// The Appwrite API, `…/v1`.
  final String endpoint;

  /// The Appwrite project.
  final String projectId;

  /// The battle.
  final String battleId;

  /// The battle's map, in the app's assets.
  final String mapId;

  @override
  List<Object?> get props => [endpoint, projectId, battleId, mapId];
}
