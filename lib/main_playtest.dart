import 'package:battle_team/app/app.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/trust_host_stub.dart'
    if (dart.library.io) 'package:battle_team/battle/trust_host_io.dart';
import 'package:battle_team/bootstrap.dart';

/// The app against the local stack, the way the playtest ran it: it signs in
/// the account `battle_host`'s `tool/playtest.dart` set up and opens the
/// battle it made, with no sign-in page. Run it with
/// `--dart-define-from-file=../../env/development.json
/// --dart-define-from-file=env/playtest.json`; without the second file it is
/// the normal app, with the certificate trusted.
///
/// The local Appwrite answers on https with Traefik's self-signed
/// certificate, which a phone does not trust: the Appwrite SDK is told to
/// accept it, and so is the host lookup (`trustHost`, `dart:io` only; the
/// browser decides for itself on the web). Appwrite sets its session cookie
/// `SameSite=None`, which `dart:io` only accepts with `Secure`, so over
/// plain http the SDK keeps no session.
Future<void> main() async {
  const playtest = PlaytestSettings.fromEnvironment();
  final host = Uri.tryParse(const String.fromEnvironment('APPWRITE_ENDPOINT'))
      ?.host;
  if (host != null && host.isNotEmpty) trustHost(host);
  await bootstrap(
    (apiClient) => playtest.complete
        ? App.playtest(apiClient, playtest)
        : App.fromApiClient(apiClient),
    trustSelfSigned: true,
  );
}
