import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/battle/battle.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/title/title.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// {@template app}
/// The app: the title, then the battle of its [battleRepository]. The
/// repositories come from the entry point, one per data source (VGV layers).
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  const new({
    required this.backendStatusRepository,
    required this.battleRepository,
    super.key,
  });

  /// The app over [apiClient], with the battle of the build settings
  /// (`--dart-define-from-file`, see [BattleSettings.fromEnvironment]).
  factory fromApiClient(AppwriteApiClient apiClient) => App(
    backendStatusRepository: BackendStatusRepository(apiClient: apiClient),
    battleRepository: BattleRepository(
      settings: const BattleSettings.fromEnvironment(),
      apiClient: apiClient,
    ),
  );

  /// Checks that the Appwrite backend answers, for the title.
  final BackendStatusRepository backendStatusRepository;

  /// The battle's data. It serves one session: the title replaces itself
  /// with the battle, which does not come back to it.
  final BattleRepository battleRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: backendStatusRepository),
        RepositoryProvider.value(value: battleRepository),
      ],
      child: const AppView(),
    );
  }
}

/// {@template app_view}
/// The `MaterialApp` of the app: its theme, its two locales (English and
/// French) and its first page, the title.
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
      home: const TitlePage(),
    );
  }
}
