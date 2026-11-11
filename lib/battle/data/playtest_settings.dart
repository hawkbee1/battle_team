import 'package:equatable/equatable.dart';

/// {@template playtest_settings}
/// What the playtest flavor signs in with and plays: the blue player's account
/// and the battle `battle_host`'s `tool/playtest.dart` set up, given at build
/// time with `--dart-define-from-file=../../env/development.json
/// --dart-define-from-file=env/playtest.json`. The normal flavors have none:
/// their players sign in and find their own battle.
/// {@endtemplate}
class PlaytestSettings extends Equatable {
  /// {@macro playtest_settings}
  const new({
    required this.email,
    required this.password,
    required this.battleId,
    this.mapId = 'saint_lo_1km',
  });

  /// The settings given at build time.
  const new fromEnvironment()
    : this(
        email: const String.fromEnvironment('BT_PLAYTEST_EMAIL'),
        password: const String.fromEnvironment('BT_PLAYTEST_PASSWORD'),
        battleId: const String.fromEnvironment('BT_PLAYTEST_BATTLE'),
      );

  /// The player's email.
  final String email;

  /// The player's password. A build-time constant of the playtest, which the
  /// tool regenerates at each run.
  final String password;

  /// The battle.
  final String battleId;

  /// The battle's map, in the app's assets.
  final String mapId;

  /// Whether every setting was given.
  bool get complete =>
      [email, password, battleId].every((value) => value.isNotEmpty);

  @override
  List<Object?> get props => [email, password, battleId, mapId];

  /// Without the email or the password: Equatable would print them in debug.
  @override
  String toString() => 'PlaytestSettings($battleId, $mapId)';
}
