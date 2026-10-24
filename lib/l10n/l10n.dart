import 'package:battle_team/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:battle_team/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
