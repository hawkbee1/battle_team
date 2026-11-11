import 'package:battle_team/app/app.dart';
import 'package:battle_team/battle/trust_host_stub.dart'
    if (dart.library.io) 'package:battle_team/battle/trust_host_io.dart';
import 'package:battle_team/bootstrap.dart';

/// The app against the local Appwrite and hosts of the development stack.
///
/// That stack answers on https with Traefik's self-signed certificate, which
/// a phone does not trust: the Appwrite SDK is told to accept it, and so is
/// the host lookup (`trustHost`, `dart:io` only; the browser decides for
/// itself on the web). Only this flavor and the playtest do: staging and
/// production never trust a certificate the system does not.
Future<void> main() async {
  final host = Uri.tryParse(const String.fromEnvironment('APPWRITE_ENDPOINT'))
      ?.host;
  if (host != null && host.isNotEmpty) trustHost(host);
  await bootstrap(App.fromApiClient, trustSelfSigned: true);
}
