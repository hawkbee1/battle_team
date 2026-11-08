import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/playtest/playtest_settings.dart';
import 'package:battle_team/playtest/view/playtest_page.dart';
import 'package:material_ui/material_ui.dart';

/// {@template playtest_app}
/// The playtest: straight into the battle of [settings] as its player, or
/// how to set it up when [settings] are missing.
/// {@endtemplate}
class PlaytestApp extends StatelessWidget {
  /// {@macro playtest_app}
  const new({
    required this.settings,
    required this.apiClient,
    super.key,
    this.home,
  });

  /// What to play.
  final PlaytestSettings settings;

  /// The Appwrite project.
  final AppwriteApiClient apiClient;

  /// The home page; the playtest by default.
  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => context.l10n.playtestTitle,
    theme: ThemeData(brightness: Brightness.dark),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home:
        home ??
        (settings.complete
            ? PlaytestPage(settings: settings, apiClient: apiClient)
            : const _MissingSettings()),
  );
}

class _MissingSettings extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.l10n.playtestMissingSettings),
      ),
    ),
  );
}
