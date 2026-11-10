import 'package:battle_team/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

export 'package:battle_team/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The localization delegates of the app's `MaterialApp`: its own, beside
/// material_ui's, which draws the Material widgets and has its own
/// localizations (Material, Cupertino and widgets).
///
/// The generated `AppLocalizations.localizationsDelegates` holds the
/// Flutter SDK's instead; with those a locale other than English fails at
/// run time, which no widget test of English shows.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
