import 'package:battle_team/bootstrap.dart';
import 'package:battle_team/playtest/playtest.dart';

/// The playtest: straight into a battle as its player (battle_host's
/// `tool/playtest.dart` sets it up). Run it with
/// `--dart-define-from-file=../../env/development.json
/// --dart-define-from-file=env/playtest.json`.
Future<void> main() async {
  await bootstrap(
    (apiClient) => PlaytestApp(
      settings: const PlaytestSettings.fromEnvironment(),
      apiClient: apiClient,
    ),
  );
}
