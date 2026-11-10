import 'dart:async';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/gen/assets.gen.dart';
import 'package:battle_team/logging/logging.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Appwrite settings passed at build time with
/// `--dart-define-from-file=../../env/<flavor>.json`.
const _appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
const _appwriteProjectId = String.fromEnvironment('APPWRITE_PROJECT_ID');

/// [trustSelfSigned] accepts the Appwrite endpoint's self-signed certificate
/// (the local Appwrite behind Traefik's default one).
Future<void> bootstrap(
  FutureOr<Widget> Function(AppwriteApiClient apiClient) builder, {
  bool trustSelfSigned = false,
}) async {
  // The Appwrite client reads the documents directory as soon as it is built.
  WidgetsFlutterBinding.ensureInitialized();

  configureLogging(release: kReleaseMode);
  FlutterError.onError = logFlutterError;

  Bloc.observer = AppBlocObserver();

  LicenseRegistry.addLicense(() async* {
    final poppins = await rootBundle.loadString(Assets.licenses.poppins.ofl);
    yield LicenseEntryWithLineBreaks(['poppins'], poppins);
  });

  if (_appwriteEndpoint.isEmpty || _appwriteProjectId.isEmpty) {
    throw StateError(
      'APPWRITE_ENDPOINT and APPWRITE_PROJECT_ID are not set. Run with '
      '--dart-define-from-file=../../env/<flavor>.json',
    );
  }

  final apiClient = AppwriteApiClient(
    endpoint: _appwriteEndpoint,
    projectId: _appwriteProjectId,
    selfSigned: trustSelfSigned,
  );

  runApp(await builder(apiClient));
}
