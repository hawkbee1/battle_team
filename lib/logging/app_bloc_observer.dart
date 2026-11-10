import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Logs the errors of every bloc and cubit, and Flutter's own.
///
/// Not their changes: a state holds what the section sees, and the logs
/// show nothing of it (decision 237).
class AppBlocObserver extends BlocObserver {
  static final _log = Logger('battle_team.AppBlocObserver');

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _log.severe('${bloc.runtimeType} failed', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

/// Logs a framework error; the handler of `FlutterError.onError`.
void logFlutterError(FlutterErrorDetails details) =>
    Logger('battle_team.FlutterError')
        .severe(details.exceptionAsString(), details.exception, details.stack);
