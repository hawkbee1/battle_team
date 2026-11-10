import 'package:equatable/equatable.dart';

/// {@template battle_settings}
/// What the playtest signs in with and plays: the Appwrite project, the
/// blue player's account and the battle, given at build time with
/// `--dart-define-from-file=../../env/development.json
/// --dart-define-from-file=env/playtest.json`. battle_host's
/// `tool/playtest.dart` writes `env/playtest.json`.
/// {@endtemplate}
class BattleSettings extends Equatable {
  /// {@macro battle_settings}
  const new({
    required this.endpoint,
    required this.projectId,
    required this.email,
    required this.password,
    required this.battleId,
    this.mapId = 'saint_lo_1km',
  });

  /// The settings given at build time.
  const new fromEnvironment()
    : this(
        endpoint: const String.fromEnvironment('APPWRITE_ENDPOINT'),
        projectId: const String.fromEnvironment('APPWRITE_PROJECT_ID'),
        email: const String.fromEnvironment('BT_PLAYTEST_EMAIL'),
        password: const String.fromEnvironment('BT_PLAYTEST_PASSWORD'),
        battleId: const String.fromEnvironment('BT_PLAYTEST_BATTLE'),
      );

  /// The Appwrite API, `…/v1`.
  final String endpoint;

  /// The Appwrite project.
  final String projectId;

  /// The player's email.
  final String email;

  /// The player's password.
  final String password;

  /// The battle.
  final String battleId;

  /// The battle's map, in the app's assets.
  final String mapId;

  /// Whether every setting was given.
  bool get complete => [
    endpoint,
    projectId,
    email,
    password,
    battleId,
  ].every((value) => value.isNotEmpty);

  @override
  List<Object?> get props => [
    endpoint,
    projectId,
    email,
    password,
    battleId,
    mapId,
  ];
}
