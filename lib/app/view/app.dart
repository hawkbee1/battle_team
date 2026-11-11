import 'dart:async';

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

const _appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
const _appwriteProjectId = String.fromEnvironment('APPWRITE_PROJECT_ID');

/// {@template app}
/// The app: the sign-in until an account is signed in, then the battle of its
/// section. The session of the last run decides the first screen. The
/// repositories come from the entry point, one per data source (VGV layers).
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  const new({
    required this.authenticationRepository,
    required this.backendStatusRepository,
    required this.battleLocator,
    required this.battleRepositoryFactory,
    super.key,
  });

  /// The app over [apiClient]: players sign up or sign in, and play the battle
  /// their section is in. The Appwrite project is the build settings'
  /// (`--dart-define-from-file`, see `bootstrap`).
  factory fromApiClient(AppwriteApiClient apiClient) => App(
    authenticationRepository: AuthenticationRepository(apiClient: apiClient),
    backendStatusRepository: BackendStatusRepository(apiClient: apiClient),
    battleLocator: AppwriteBattleLocator(apiClient: apiClient),
    battleRepositoryFactory: BattleRepositoryFactory(
      apiClient: apiClient,
      endpoint: _appwriteEndpoint,
      projectId: _appwriteProjectId,
    ),
  );

  /// The playtest flavor over [apiClient]: it signs in the account of
  /// [settings] at start and plays the one battle they name, as the playtest
  /// always did. The sign-in page shows only when that sign-in fails.
  factory playtest(AppwriteApiClient apiClient, PlaytestSettings settings) =>
      App(
        authenticationRepository: AuthenticationRepository(
          apiClient: apiClient,
          signInAtStart: (email: settings.email, password: settings.password),
        ),
        backendStatusRepository: BackendStatusRepository(apiClient: apiClient),
        battleLocator: FixedBattleLocator((
          battleId: settings.battleId,
          mapId: settings.mapId,
        )),
        battleRepositoryFactory: BattleRepositoryFactory(
          apiClient: apiClient,
          endpoint: _appwriteEndpoint,
          projectId: _appwriteProjectId,
        ),
      );

  /// The account: sign up, sign in, log out.
  final AuthenticationRepository authenticationRepository;

  /// Checks that the Appwrite backend answers, for the sign-in page.
  final BackendStatusRepository backendStatusRepository;

  /// Finds the battle of the signed-in account.
  final BattleLocator battleLocator;

  /// Makes the repository of a battle: one per battle entered.
  final BattleRepositoryFactory battleRepositoryFactory;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authenticationRepository),
        RepositoryProvider.value(value: backendStatusRepository),
        RepositoryProvider<BattleLocator>.value(value: battleLocator),
        RepositoryProvider.value(value: battleRepositoryFactory),
      ],
      child: BlocProvider(
        create: (context) {
          final cubit = AuthenticationCubit(
            repository: authenticationRepository,
          );
          unawaited(cubit.start());
          return cubit;
        },
        child: const AppView(),
      ),
    );
  }
}

/// {@template app_view}
/// The `MaterialApp` of the app: its theme, its two locales (English and
/// French) and its first page, the gate between the sign-in and the battle.
/// Needs the cubit and the repositories `App` provides above it.
/// {@endtemplate}
class AppView extends StatelessWidget {
  /// {@macro app_view}
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.battleTitle,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A48DF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E2228),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AuthenticationGate(
        signedIn: (context, accountId) => BattleEntryPage(accountId: accountId),
      ),
    );
  }
}
