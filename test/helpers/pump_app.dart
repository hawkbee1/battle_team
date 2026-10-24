import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/game/cubit/cubit.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/loading/loading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockingjay/mockingjay.dart';

import 'helpers.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    MockNavigator? navigator,
    PreloadCubit? preloadCubit,
    AudioCubit? audioCubit,
    BackendStatusRepository? backendStatusRepository,
  }) {
    return pumpWidget(
      RepositoryProvider.value(
        value: backendStatusRepository ?? _reachableBackendStatusRepository(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: preloadCubit ?? MockPreloadCubit()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: navigator != null
                ? MockNavigatorProvider(navigator: navigator, child: widget)
                : widget,
          ),
        ),
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
