import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/authentication/authentication.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockingjay/mockingjay.dart';

import 'helpers.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] in the app's `MaterialApp`, with the backend status
  /// repository and, when given, the account's [authenticationRepository] and
  /// [authenticationCubit] above it.
  Future<void> pumpApp(
    Widget widget, {
    MockNavigator? navigator,
    BackendStatusRepository? backendStatusRepository,
    AuthenticationRepository? authenticationRepository,
    AuthenticationCubit? authenticationCubit,
    Locale? locale,
  }) {
    Widget app = MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: navigator != null
          ? MockNavigatorProvider(navigator: navigator, child: widget)
          : widget,
    );
    if (authenticationCubit != null) {
      app = BlocProvider.value(value: authenticationCubit, child: app);
    }
    if (authenticationRepository != null) {
      app = RepositoryProvider.value(
        value: authenticationRepository,
        child: app,
      );
    }
    return pumpWidget(
      RepositoryProvider.value(
        value: backendStatusRepository ?? _reachableBackendStatusRepository(),
        child: app,
      ),
    );
  }
}

/// A repository whose backend always answers, so pages that check the
/// connection settle.
BackendStatusRepository _reachableBackendStatusRepository() {
  final repository = MockBackendStatusRepository();
  when(repository.checkConnection).thenAnswer((_) async {});
  return repository;
}
