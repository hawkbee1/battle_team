import 'package:battle_team/app/app.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/battle/trust_host_stub.dart'
    if (dart.library.io) 'package:battle_team/battle/trust_host_io.dart';
import 'package:battle_team/bootstrap.dart';

/// The app against the local stack, the way the playtest ran it: straight to
/// the battle `battle_host`'s `tool/playtest.dart` set up. Run it with
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
  const settings = BattleSettings.fromEnvironment();
  final host = Uri.tryParse(settings.endpoint)?.host;
  if (host != null && host.isNotEmpty) trustHost(host);
  await bootstrap(App.fromApiClient, trustSelfSigned: true);
}
