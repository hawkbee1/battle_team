import 'package:battle_team/bootstrap.dart';
import 'package:battle_team/playtest/playtest.dart';
import 'package:battle_team/playtest/trust_host_stub.dart'
    if (dart.library.io) 'package:battle_team/playtest/trust_host_io.dart';

/// The playtest: straight into a battle as its player (battle_host's
/// `tool/playtest.dart` sets it up). Run it with
/// `--dart-define-from-file=../../env/development.json
/// --dart-define-from-file=env/playtest.json`.
///
/// The local Appwrite answers on https with Traefik's self-signed
/// certificate, which a phone does not trust: the Appwrite SDK is told to
/// accept it, and so is the host lookup (`trustHost`, `dart:io` only; the
/// browser decides for itself on the web). Appwrite sets its session cookie
/// `SameSite=None`, which `dart:io` only accepts with `Secure`, so over
/// plain http the SDK keeps no session.
Future<void> main() async {
  const settings = PlaytestSettings.fromEnvironment();
  final host = Uri.tryParse(settings.endpoint)?.host;
  if (host != null && host.isNotEmpty) trustHost(host);
  await bootstrap(
    (apiClient) => PlaytestApp(settings: settings, apiClient: apiClient),
    trustSelfSigned: true,
  );
}
